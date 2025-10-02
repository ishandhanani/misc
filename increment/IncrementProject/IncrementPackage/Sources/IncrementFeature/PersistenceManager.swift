import Foundation
import OSLog

/// Manages local persistence for sessions, exercise states, and profiles
@MainActor
class PersistenceManager {
    static let shared = PersistenceManager()

    private let userDefaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()
    private let logger = Logger(subsystem: "com.increment", category: "PersistenceManager")

    // Keys
    private enum Keys {
        static let sessions = "increment.sessions"
        static let exerciseStates = "increment.exerciseStates"
        static let exerciseProfiles = "increment.exerciseProfiles"
        static let workoutPlans = "increment.workoutPlans"
        static let currentSession = "increment.currentSession"
    }

    enum PersistenceError: Error {
        case encodingFailed(String, Error)
        case decodingFailed(String, Error)
        case dataCorrupted(String)

        var localizedDescription: String {
            switch self {
            case .encodingFailed(let key, let error):
                return "Failed to encode data for key '\(key)': \(error.localizedDescription)"
            case .decodingFailed(let key, let error):
                return "Failed to decode data for key '\(key)': \(error.localizedDescription)"
            case .dataCorrupted(let key):
                return "Data corrupted for key '\(key)'"
            }
        }
    }

    private init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: - Sessions

    func saveSessions(_ sessions: [Session]) {
        do {
            let data = try encoder.encode(sessions)
            userDefaults.set(data, forKey: Keys.sessions)
            logger.debug("Successfully saved \(sessions.count) sessions")
        } catch {
            let persistenceError = PersistenceError.encodingFailed(Keys.sessions, error)
            logger.error("\(persistenceError.localizedDescription)")
        }
    }

    func loadSessions() -> [Session] {
        guard let data = userDefaults.data(forKey: Keys.sessions) else {
            logger.debug("No sessions data found")
            return []
        }

        do {
            let sessions = try decoder.decode([Session].self, from: data)
            logger.debug("Successfully loaded \(sessions.count) sessions")
            return sessions
        } catch {
            let persistenceError = PersistenceError.decodingFailed(Keys.sessions, error)
            logger.error("\(persistenceError.localizedDescription)")
            return []
        }
    }

    func saveCurrentSession(_ session: Session?) {
        guard let session = session else {
            userDefaults.removeObject(forKey: Keys.currentSession)
            logger.debug("Removed current session")
            return
        }

        do {
            let data = try encoder.encode(session)
            userDefaults.set(data, forKey: Keys.currentSession)
            logger.debug("Successfully saved current session")
        } catch {
            let persistenceError = PersistenceError.encodingFailed(Keys.currentSession, error)
            logger.error("\(persistenceError.localizedDescription)")
        }
    }

    func loadCurrentSession() -> Session? {
        guard let data = userDefaults.data(forKey: Keys.currentSession) else {
            logger.debug("No current session data found")
            return nil
        }

        do {
            let session = try decoder.decode(Session.self, from: data)
            logger.debug("Successfully loaded current session")
            return session
        } catch {
            let persistenceError = PersistenceError.decodingFailed(Keys.currentSession, error)
            logger.error("\(persistenceError.localizedDescription)")
            return nil
        }
    }

    func isSessionStale(_ session: Session, threshold: TimeInterval = 86400) -> Bool {
        // Consider a session stale if it's more than threshold seconds old (default: 24 hours)
        return Date().timeIntervalSince(session.lastUpdated) > threshold
    }

    func clearCurrentSession() {
        userDefaults.removeObject(forKey: Keys.currentSession)
        logger.debug("Cleared current session")
    }

    // MARK: - Exercise States

    func saveExerciseStates(_ states: [UUID: ExerciseState]) {
        do {
            let data = try encoder.encode(states)
            userDefaults.set(data, forKey: Keys.exerciseStates)
            logger.debug("Successfully saved \(states.count) exercise states")
        } catch {
            let persistenceError = PersistenceError.encodingFailed(Keys.exerciseStates, error)
            logger.error("\(persistenceError.localizedDescription)")
        }
    }

    func loadExerciseStates() -> [UUID: ExerciseState] {
        guard let data = userDefaults.data(forKey: Keys.exerciseStates) else {
            logger.debug("No exercise states data found")
            return [:]
        }

        do {
            let states = try decoder.decode([UUID: ExerciseState].self, from: data)
            logger.debug("Successfully loaded \(states.count) exercise states")
            return states
        } catch {
            let persistenceError = PersistenceError.decodingFailed(Keys.exerciseStates, error)
            logger.error("\(persistenceError.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Exercise Profiles

    func saveExerciseProfiles(_ profiles: [UUID: ExerciseProfile]) {
        do {
            let data = try encoder.encode(profiles)
            userDefaults.set(data, forKey: Keys.exerciseProfiles)
            logger.debug("Successfully saved \(profiles.count) exercise profiles")
        } catch {
            let persistenceError = PersistenceError.encodingFailed(Keys.exerciseProfiles, error)
            logger.error("\(persistenceError.localizedDescription)")
        }
    }

    func loadExerciseProfiles() -> [UUID: ExerciseProfile] {
        guard let data = userDefaults.data(forKey: Keys.exerciseProfiles) else {
            logger.debug("No exercise profiles data found")
            return [:]
        }

        do {
            let profiles = try decoder.decode([UUID: ExerciseProfile].self, from: data)
            logger.debug("Successfully loaded \(profiles.count) exercise profiles")
            return profiles
        } catch {
            let persistenceError = PersistenceError.decodingFailed(Keys.exerciseProfiles, error)
            logger.error("\(persistenceError.localizedDescription)")
            return [:]
        }
    }

    // MARK: - Workout Plans

    func saveWorkoutPlans(_ plans: [WorkoutPlan]) {
        do {
            let data = try encoder.encode(plans)
            userDefaults.set(data, forKey: Keys.workoutPlans)
            logger.debug("Successfully saved \(plans.count) workout plans")
        } catch {
            let persistenceError = PersistenceError.encodingFailed(Keys.workoutPlans, error)
            logger.error("\(persistenceError.localizedDescription)")
        }
    }

    func loadWorkoutPlans() -> [WorkoutPlan] {
        guard let data = userDefaults.data(forKey: Keys.workoutPlans) else {
            logger.debug("No workout plans data found")
            return []
        }

        do {
            let plans = try decoder.decode([WorkoutPlan].self, from: data)
            logger.debug("Successfully loaded \(plans.count) workout plans")
            return plans
        } catch {
            let persistenceError = PersistenceError.decodingFailed(Keys.workoutPlans, error)
            logger.error("\(persistenceError.localizedDescription)")
            return []
        }
    }

    // MARK: - Utilities

    func clearAll() {
        userDefaults.removeObject(forKey: Keys.sessions)
        userDefaults.removeObject(forKey: Keys.exerciseStates)
        userDefaults.removeObject(forKey: Keys.exerciseProfiles)
        userDefaults.removeObject(forKey: Keys.workoutPlans)
        userDefaults.removeObject(forKey: Keys.currentSession)
        userDefaults.synchronize() // Force write to disk
    }

    func exportData() -> [String: Any] {
        let sessions = loadSessions().compactMap { session -> Data? in
            do {
                return try encoder.encode(session)
            } catch {
                logger.error("Failed to encode session during export: \(error.localizedDescription)")
                return nil
            }
        }

        return [
            "sessions": sessions,
            "exerciseStates": loadExerciseStates(),
            "exerciseProfiles": loadExerciseProfiles(),
            "workoutPlans": loadWorkoutPlans()
        ]
    }
}