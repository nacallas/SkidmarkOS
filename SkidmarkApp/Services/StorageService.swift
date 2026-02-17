import Foundation

/// Protocol defining storage operations for league data, context, and cached information
protocol StorageService {
    // League Connections
    func saveLeagueConnections(_ connections: [LeagueConnection]) throws
    func loadLeagueConnections() throws -> [LeagueConnection]
    
    // League Context
    func saveLeagueContext(_ context: LeagueContext, forLeagueId leagueId: String) throws
    func loadLeagueContext(forLeagueId leagueId: String) throws -> LeagueContext?
    
    // Cached League Data
    func saveCachedLeagueData(_ teams: [Team], forLeagueId leagueId: String, roastHash: Int?) throws
    func loadCachedLeagueData(forLeagueId leagueId: String) throws -> (teams: [Team], timestamp: Date, roastHash: Int?)?
    
    // Cache Staleness
    func isCacheStale(forLeagueId leagueId: String) -> Bool
    func getCacheAge(forLeagueId leagueId: String) -> TimeInterval?
    
    // Last Viewed League
    func saveLastViewedLeagueId(_ leagueId: String)
    func loadLastViewedLeagueId() -> String?
    
    // Weekly Roast Cache
    func saveWeeklyRoasts(_ cache: WeeklyRoastCache) throws
    func loadWeeklyRoasts(forLeagueId: String, week: Int) throws -> WeeklyRoastCache?
    func deleteAllRoasts(forLeagueId: String) throws
    func availableRoastWeeks(forLeagueId: String) throws -> [Int]
    
    // Data Cleanup
    func clearDataForLeague(leagueId: String) throws
}

/// Errors that can occur during storage operations
enum StorageError: LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case fileOperationFailed(Error)
    case dataNotFound
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed(let error):
            return "Failed to encode data: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode data: \(error.localizedDescription)"
        case .fileOperationFailed(let error):
            return "File operation failed: \(error.localizedDescription)"
        case .dataNotFound:
            return "Requested data not found"
        }
    }
}

/// Default implementation of StorageService using UserDefaults and FileManager
final class DefaultStorageService: StorageService {
    private let userDefaults: UserDefaults
    private let fileManager: FileManager
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    
    // UserDefaults keys
    private let leagueConnectionsKey = "skidmark.leagueConnections"
    private let lastViewedLeagueKey = "skidmark.lastViewedLeagueId"
    
    // Cache expiration policy: 24 hours
    private let cacheExpirationInterval: TimeInterval = 24 * 60 * 60
    
    init(
        userDefaults: UserDefaults = .standard,
        fileManager: FileManager = .default
    ) {
        self.userDefaults = userDefaults
        self.fileManager = fileManager
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
        
        // Configure date encoding/decoding strategy
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }
    
    // MARK: - League Connections
    
    func saveLeagueConnections(_ connections: [LeagueConnection]) throws {
        do {
            let data = try encoder.encode(connections)
            userDefaults.set(data, forKey: leagueConnectionsKey)
        } catch {
            throw StorageError.encodingFailed(error)
        }
    }
    
    func loadLeagueConnections() throws -> [LeagueConnection] {
        guard let data = userDefaults.data(forKey: leagueConnectionsKey) else {
            return []
        }
        
        do {
            return try decoder.decode([LeagueConnection].self, from: data)
        } catch {
            throw StorageError.decodingFailed(error)
        }
    }
    
    // MARK: - Last Viewed League
    
    func saveLastViewedLeagueId(_ leagueId: String) {
        userDefaults.set(leagueId, forKey: lastViewedLeagueKey)
    }
    
    func loadLastViewedLeagueId() -> String? {
        return userDefaults.string(forKey: lastViewedLeagueKey)
    }
    
    // MARK: - League Context
    
    func saveLeagueContext(_ context: LeagueContext, forLeagueId leagueId: String) throws {
        let fileURL = contextFileURL(forLeagueId: leagueId)
        
        do {
            try ensureDirectoryExists(for: fileURL)
            let data = try encoder.encode(context)
            try data.write(to: fileURL, options: .atomic)
        } catch let error as EncodingError {
            throw StorageError.encodingFailed(error)
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    func loadLeagueContext(forLeagueId leagueId: String) throws -> LeagueContext? {
        let fileURL = contextFileURL(forLeagueId: leagueId)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(LeagueContext.self, from: data)
        } catch let error as DecodingError {
            throw StorageError.decodingFailed(error)
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    // MARK: - Cached League Data
    
    func saveCachedLeagueData(_ teams: [Team], forLeagueId leagueId: String, roastHash: Int? = nil) throws {
        let fileURL = cacheFileURL(forLeagueId: leagueId)
        
        let cacheData = CachedLeagueData(teams: teams, timestamp: Date(), roastHash: roastHash)
        
        do {
            try ensureDirectoryExists(for: fileURL)
            let data = try encoder.encode(cacheData)
            try data.write(to: fileURL, options: .atomic)
        } catch let error as EncodingError {
            throw StorageError.encodingFailed(error)
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    func loadCachedLeagueData(forLeagueId leagueId: String) throws -> (teams: [Team], timestamp: Date, roastHash: Int?)? {
        let fileURL = cacheFileURL(forLeagueId: leagueId)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cacheData = try decoder.decode(CachedLeagueData.self, from: data)
            return (cacheData.teams, cacheData.timestamp, cacheData.roastHash)
        } catch let error as DecodingError {
            throw StorageError.decodingFailed(error)
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    // MARK: - Cache Staleness
    
    func isCacheStale(forLeagueId leagueId: String) -> Bool {
        guard let age = getCacheAge(forLeagueId: leagueId) else {
            return true // No cache means stale
        }
        return age > cacheExpirationInterval
    }
    
    func getCacheAge(forLeagueId leagueId: String) -> TimeInterval? {
        let fileURL = cacheFileURL(forLeagueId: leagueId)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            let cacheData = try decoder.decode(CachedLeagueData.self, from: data)
            return Date().timeIntervalSince(cacheData.timestamp)
        } catch {
            return nil
        }
    }
    
    // MARK: - Weekly Roast Cache
    
    func saveWeeklyRoasts(_ cache: WeeklyRoastCache) throws {
        let fileURL = roastCacheFileURL(forLeagueId: cache.leagueId, week: cache.weekNumber)
        
        do {
            try ensureDirectoryExists(for: fileURL)
            let data = try encoder.encode(cache)
            try data.write(to: fileURL, options: .atomic)
        } catch let error as EncodingError {
            throw StorageError.encodingFailed(error)
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    func loadWeeklyRoasts(forLeagueId leagueId: String, week: Int) throws -> WeeklyRoastCache? {
        let fileURL = roastCacheFileURL(forLeagueId: leagueId, week: week)
        
        guard fileManager.fileExists(atPath: fileURL.path) else {
            return nil
        }
        
        do {
            let data = try Data(contentsOf: fileURL)
            return try decoder.decode(WeeklyRoastCache.self, from: data)
        } catch let error as DecodingError {
            throw StorageError.decodingFailed(error)
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    func deleteAllRoasts(forLeagueId leagueId: String) throws {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let prefix = "league_\(leagueId)_roasts_week_"
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            for fileURL in contents where fileURL.lastPathComponent.hasPrefix(prefix) && fileURL.pathExtension == "json" {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    func availableRoastWeeks(forLeagueId leagueId: String) throws -> [Int] {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let prefix = "league_\(leagueId)_roasts_week_"
        
        do {
            let contents = try fileManager.contentsOfDirectory(at: documentsDirectory, includingPropertiesForKeys: nil)
            return contents.compactMap { fileURL -> Int? in
                let name = fileURL.lastPathComponent
                guard name.hasPrefix(prefix), name.hasSuffix(".json") else { return nil }
                let weekStr = name.dropFirst(prefix.count).dropLast(5) // drop ".json"
                return Int(weekStr)
            }.sorted()
        } catch {
            throw StorageError.fileOperationFailed(error)
        }
    }
    
    // MARK: - Data Cleanup
    
    func clearDataForLeague(leagueId: String) throws {
        let contextURL = contextFileURL(forLeagueId: leagueId)
        let cacheURL = cacheFileURL(forLeagueId: leagueId)
        
        var errors: [Error] = []
        
        // Remove context file if it exists
        if fileManager.fileExists(atPath: contextURL.path) {
            do {
                try fileManager.removeItem(at: contextURL)
            } catch {
                errors.append(error)
            }
        }
        
        // Remove cache file if it exists
        if fileManager.fileExists(atPath: cacheURL.path) {
            do {
                try fileManager.removeItem(at: cacheURL)
            } catch {
                errors.append(error)
            }
        }
        
        // Remove all roast cache files for this league
        do {
            try deleteAllRoasts(forLeagueId: leagueId)
        } catch {
            errors.append(error)
        }
        
        // If any errors occurred, throw the first one
        if let firstError = errors.first {
            throw StorageError.fileOperationFailed(firstError)
        }
    }
    
    // MARK: - Private Helpers
    
    private func ensureDirectoryExists(for fileURL: URL) throws {
        let directory = fileURL.deletingLastPathComponent()
        if !fileManager.fileExists(atPath: directory.path) {
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
    }
    
    private func contextFileURL(forLeagueId leagueId: String) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("league_\(leagueId)_context.json")
    }
    
    private func cacheFileURL(forLeagueId leagueId: String) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("league_\(leagueId)_cache.json")
    }
    
    private func roastCacheFileURL(forLeagueId leagueId: String, week: Int) -> URL {
        let documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsDirectory.appendingPathComponent("league_\(leagueId)_roasts_week_\(week).json")
    }
}

// MARK: - Supporting Types

private struct CachedLeagueData: Codable {
    let teams: [Team]
    let timestamp: Date
    let roastHash: Int?
}
