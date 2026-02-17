import Foundation

/// View model managing league context editing and persistence
@MainActor @Observable
class LeagueContextViewModel {
    // MARK: - Published Properties
    
    var insideJokes: [LeagueContext.InsideJoke] = []
    var personalities: [LeagueContext.PlayerPersonality] = []
    var sackoPunishment: String = ""
    var cultureNotes: String = ""
    var saveState: SaveState = .idle
    
    // MARK: - Save State
    
    enum SaveState: Equatable {
        case idle
        case saving
        case saved
        case failed(String)
    }
    
    // MARK: - Dependencies
    
    private let storageService: StorageService
    
    // MARK: - Private State
    
    private var currentLeagueId: String?
    
    // MARK: - Initialization
    
    init(storageService: StorageService = DefaultStorageService()) {
        self.storageService = storageService
    }
    
    // MARK: - Public Methods
    
    /// Loads league context for the specified league
    /// - Parameter leagueId: The league ID to load context for
    func loadContext(forLeagueId leagueId: String) {
        currentLeagueId = leagueId
        
        do {
            if let context = try storageService.loadLeagueContext(forLeagueId: leagueId) {
                insideJokes = context.insideJokes
                personalities = context.personalities
                sackoPunishment = context.sackoPunishment
                cultureNotes = context.cultureNotes
            } else {
                // No context exists yet, use empty defaults
                let emptyContext = LeagueContext.empty
                insideJokes = emptyContext.insideJokes
                personalities = emptyContext.personalities
                sackoPunishment = emptyContext.sackoPunishment
                cultureNotes = emptyContext.cultureNotes
            }
            saveState = .idle
        } catch {
            saveState = .failed("Failed to load context: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Inside Jokes Management
    
    /// Adds a new inside joke
    /// - Parameters:
    ///   - term: The term or phrase
    ///   - explanation: The explanation of the joke
    func addInsideJoke(term: String, explanation: String) {
        let joke = LeagueContext.InsideJoke(
            id: UUID(),
            term: term,
            explanation: explanation
        )
        insideJokes.append(joke)
    }
    
    /// Edits an existing inside joke
    /// - Parameters:
    ///   - id: The ID of the joke to edit
    ///   - term: The updated term
    ///   - explanation: The updated explanation
    func editInsideJoke(id: UUID, term: String, explanation: String) {
        guard let index = insideJokes.firstIndex(where: { $0.id == id }) else { return }
        insideJokes[index].term = term
        insideJokes[index].explanation = explanation
    }
    
    /// Removes an inside joke
    /// - Parameter id: The ID of the joke to remove
    func removeInsideJoke(id: UUID) {
        insideJokes.removeAll { $0.id == id }
    }
    
    // MARK: - Personalities Management
    
    /// Adds a new player personality
    /// - Parameters:
    ///   - playerName: The player's name
    ///   - description: The personality description
    func addPersonality(playerName: String, description: String) {
        let personality = LeagueContext.PlayerPersonality(
            id: UUID(),
            playerName: playerName,
            description: description
        )
        personalities.append(personality)
    }
    
    /// Edits an existing player personality
    /// - Parameters:
    ///   - id: The ID of the personality to edit
    ///   - playerName: The updated player name
    ///   - description: The updated description
    func editPersonality(id: UUID, playerName: String, description: String) {
        guard let index = personalities.firstIndex(where: { $0.id == id }) else { return }
        personalities[index].playerName = playerName
        personalities[index].description = description
    }
    
    /// Removes a player personality
    /// - Parameter id: The ID of the personality to remove
    func removePersonality(id: UUID) {
        personalities.removeAll { $0.id == id }
    }
    
    // MARK: - Other Context Updates
    
    /// Updates the sacko punishment description
    /// - Parameter punishment: The new punishment description
    func updateSacko(_ punishment: String) {
        sackoPunishment = punishment
    }
    
    /// Updates the culture notes
    /// - Parameter notes: The new culture notes
    func updateCulture(_ notes: String) {
        cultureNotes = notes
    }
    
    // MARK: - Persistence
    
    /// Saves the current context to storage
    func saveContext() {
        guard let leagueId = currentLeagueId else {
            saveState = .failed("No league selected")
            return
        }
        
        saveState = .saving
        
        let context = LeagueContext(
            insideJokes: insideJokes,
            personalities: personalities,
            sackoPunishment: sackoPunishment,
            cultureNotes: cultureNotes
        )
        
        do {
            try storageService.saveLeagueContext(context, forLeagueId: leagueId)
            saveState = .saved
            
            // Reset to idle after a brief delay
            Task {
                try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                if case .saved = saveState {
                    saveState = .idle
                }
            }
        } catch {
            saveState = .failed("Failed to save context: \(error.localizedDescription)")
        }
    }
    
    /// Returns the current context as a LeagueContext object
    func getCurrentContext() -> LeagueContext {
        LeagueContext(
            insideJokes: insideJokes,
            personalities: personalities,
            sackoPunishment: sackoPunishment,
            cultureNotes: cultureNotes
        )
    }
    
    /// Computed property for accessing the current context
    var context: LeagueContext {
        getCurrentContext()
    }
}
