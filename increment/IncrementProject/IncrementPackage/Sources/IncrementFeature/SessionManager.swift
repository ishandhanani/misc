import Foundation
import Combine
import Observation

/// Manages the current workout session state
@Observable
@MainActor
public class SessionManager {
    // MARK: - Observable State

    public var currentSession: Session?
    public var currentExerciseIndex: Int = 0
    public var currentSetIndex: Int = 0
    public var sessionState: SessionState = .intro
    public var currentExerciseLog: ExerciseSessionLog?
    public var nextPrescription: (reps: Int, weight: Double)?
    public var isFirstExercise: Bool = true

    // MARK: - Data

    public var workoutPlans: [WorkoutPlan] = []
    public var exerciseProfiles: [UUID: ExerciseProfile] = [:]
    public var exerciseStates: [UUID: ExerciseState] = [:]

    // Timer management
    private var restTimer: RestTimer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Session State

    public enum SessionState: Equatable {
        case intro
        case preWorkout
        case stretching(timeRemaining: Int)  // 5-minute stretching countdown
        case warmup(step: Int)  // 0 = 50%×5, 1 = 70%×3
        case load
        case workingSet
        case rest(timeRemaining: Int)
        case review
        case done
    }

    // MARK: - Initialization

    public init() {
        loadDefaultExercises()
        loadDefaultWorkoutPlan()
        loadPersistedState()
    }

    // MARK: - Resume State

    public var hasResumableSession: Bool {
        guard let session = currentSession, session.isActive else {
            return false
        }

        // Check if session is not stale (within 24 hours)
        return !PersistenceManager.shared.isSessionStale(session)
    }

    public func resumeSession() {
        print("🔄 resumeSession() called")
        print("🔄 currentSession: \(currentSession != nil)")
        print("🔄 isActive: \(currentSession?.isActive ?? false)")

        guard let session = currentSession,
              session.isActive,
              !PersistenceManager.shared.isSessionStale(session) else {
            print("🔄 resumeSession() guard failed")
            return
        }

        print("🔄 resumeSession() proceeding with resume")

        // Restore exercise index
        if let exerciseIndex = session.currentExerciseIndex {
            currentExerciseIndex = exerciseIndex
        }

        // Restore set index
        if let setIndex = session.currentSetIndex {
            currentSetIndex = setIndex
        }

        // Restore session state first
        if let stateRaw = session.sessionStateRaw, !stateRaw.isEmpty {
            sessionState = deserializeSessionState(stateRaw) ?? .preWorkout
            print("🔄 Restored sessionState from raw: \(stateRaw) -> \(sessionState)")
        } else {
            // Fallback: if no state saved, determine based on session progress
            if session.preWorkoutFeeling != nil && session.exerciseLogs.isEmpty {
                // Had pre-workout feeling but no exercises logged yet - likely in stretching or warmup
                sessionState = .preWorkout
            } else if !session.exerciseLogs.isEmpty {
                // Has exercise logs - go to review of last exercise
                sessionState = .review
            } else {
                // Unknown state - start at pre-workout
                sessionState = .preWorkout
            }
            print("🔄 Fallback sessionState set to: \(sessionState)")
        }

        // Restore current exercise log
        // First try to restore the in-progress exercise log saved in the session
        if let savedLog = session.currentExerciseLog {
            currentExerciseLog = savedLog
            print("🔄 Restored currentExerciseLog from session: \(savedLog.exerciseId)")
        } else if currentExerciseIndex < session.exerciseLogs.count {
            // Fall back to completed exercise log at this index
            currentExerciseLog = session.exerciseLogs[currentExerciseIndex]
            print("🔄 Restored currentExerciseLog from exerciseLogs at index \(currentExerciseIndex)")
        } else if let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }),
                  currentExerciseIndex < plan.order.count {
            // Exercise was started but not logged yet - create a new log
            let exerciseId = plan.order[currentExerciseIndex]
            if let profile = exerciseProfiles[exerciseId] {
                let startWeight = exerciseStates[exerciseId]?.lastStartLoad ?? 45.0
                currentExerciseLog = ExerciseSessionLog(
                    exerciseId: exerciseId,
                    startWeight: startWeight
                )
                print("🔄 Created new currentExerciseLog for exerciseId: \(exerciseId)")
            } else {
                print("🔄 ERROR: No profile found for exerciseId: \(exerciseId)")
            }
        } else {
            print("🔄 ERROR: Could not restore currentExerciseLog - no valid source")
        }

        print("🔄 Final currentExerciseLog: \(currentExerciseLog?.exerciseId.uuidString ?? "nil")")

        // Restore prescription from last set log if available
        if let lastSet = currentExerciseLog?.setLogs.last {
            nextPrescription = (reps: lastSet.targetReps, weight: lastSet.targetWeight)
        }

        // If still no prescription and we're in a state that needs one, compute it
        if nextPrescription == nil {
            if case .workingSet = sessionState {
                computeInitialPrescription()
            } else if case .rest = sessionState {
                computeInitialPrescription()
            }
        }

        // Note: Timer states (stretching, rest) cannot be fully restored
        // Users will need to skip or restart timers
    }

    public func discardSession() {
        print("🗑️ discardSession() called")
        currentSession = nil
        currentExerciseIndex = 0
        currentSetIndex = 0
        sessionState = .intro
        currentExerciseLog = nil
        nextPrescription = nil
        isFirstExercise = true

        PersistenceManager.shared.clearCurrentSession()
        print("🗑️ discardSession() completed, sessionState = .intro")
    }

    private func serializeSessionState(_ state: SessionState) -> String {
        switch state {
        case .intro:
            return "intro"
        case .preWorkout:
            return "preWorkout"
        case .stretching(let timeRemaining):
            return "stretching:\(timeRemaining)"
        case .warmup(let step):
            return "warmup:\(step)"
        case .load:
            return "load"
        case .workingSet:
            return "workingSet"
        case .rest(let timeRemaining):
            return "rest:\(timeRemaining)"
        case .review:
            return "review"
        case .done:
            return "done"
        }
    }

    private func deserializeSessionState(_ raw: String) -> SessionState? {
        let components = raw.split(separator: ":")
        guard let first = components.first else { return nil }

        switch first {
        case "intro":
            return .intro
        case "preWorkout":
            return .preWorkout
        case "stretching":
            if components.count > 1, let time = Int(components[1]) {
                return .stretching(timeRemaining: time)
            }
            return .stretching(timeRemaining: 0)
        case "warmup":
            if components.count > 1, let step = Int(components[1]) {
                return .warmup(step: step)
            }
            return .warmup(step: 0)
        case "load":
            return .load
        case "workingSet":
            return .workingSet
        case "rest":
            if components.count > 1, let time = Int(components[1]) {
                return .rest(timeRemaining: time)
            }
            return .rest(timeRemaining: 0)
        case "review":
            return .review
        case "done":
            return .done
        default:
            return nil
        }
    }

    // MARK: - Session Control

    public func startSession(workoutPlanId: UUID) {
        guard let plan = workoutPlans.first(where: { $0.id == workoutPlanId }) else { return }

        currentSession = Session(workoutPlanId: plan.id)
        currentExerciseIndex = 0
        currentSetIndex = 0
        isFirstExercise = true

        // Persist exercise profiles so they're available after app restart
        PersistenceManager.shared.saveExerciseProfiles(exerciseProfiles)

        // Show pre-workout feeling screen
        sessionState = .preWorkout
    }

    public func logPreWorkoutFeeling(_ feeling: PreWorkoutFeeling) {
        currentSession?.preWorkoutFeeling = feeling
        persistSession()

        // Start stretching phase (5 minutes = 300 seconds)
        startStretchingPhase()
    }

    // MARK: - Stretching Phase

    public func startStretchingPhase() {
        let stretchDuration = 300  // 5 minutes

        // Create new timer
        let timer = RestTimer()
        restTimer = timer

        // Start timer
        timer.start(duration: stretchDuration)

        // Initial state
        sessionState = .stretching(timeRemaining: stretchDuration)
        persistSession()

        // Observe timer updates
        timer.$timeRemaining
            .sink { [weak self] remaining in
                self?.sessionState = .stretching(timeRemaining: remaining)
            }
            .store(in: &cancellables)
    }

    public func skipStretching() {
        // Stop the stretching timer
        restTimer?.stop()
        restTimer = nil

        // Start first exercise
        guard let plan = workoutPlans.first(where: { $0.id == currentSession?.workoutPlanId ?? UUID() }),
              let firstExerciseId = plan.order.first else { return }

        startExercise(exerciseId: firstExerciseId)
    }

    public func finishStretching() {
        // Stop the stretching timer
        restTimer?.stop()
        restTimer = nil

        // Start first exercise
        guard let plan = workoutPlans.first(where: { $0.id == currentSession?.workoutPlanId ?? UUID() }),
              let firstExerciseId = plan.order.first else { return }

        startExercise(exerciseId: firstExerciseId)
    }

    public func startExercise(exerciseId: UUID) {
        guard exerciseProfiles[exerciseId] != nil else { return }

        // Get starting weight from state or use default
        let startWeight = exerciseStates[exerciseId]?.lastStartLoad ?? 45.0  // Default bar weight

        currentExerciseLog = ExerciseSessionLog(
            exerciseId: exerciseId,
            startWeight: startWeight
        )

        currentSetIndex = 0

        // Only do warmups for the first exercise
        if isFirstExercise {
            sessionState = .warmup(step: 0)
            isFirstExercise = false
        } else {
            // Skip warmups, go directly to load
            sessionState = .load
            computeInitialPrescription()
        }

        persistSession()
    }

    // MARK: - Warmup Flow

    public func advanceWarmup() {
        guard case .warmup(let step) = sessionState else { return }
        guard let exerciseLog = currentExerciseLog,
              exerciseProfiles[exerciseLog.exerciseId] != nil else { return }

        if step == 0 {
            // Move to 70%×3
            sessionState = .warmup(step: 1)
        } else {
            // Warmup complete, move to load
            sessionState = .load
            computeInitialPrescription()
        }
    }

    public func getWarmupPrescription() -> (weight: Double, reps: Int)? {
        guard case .warmup(let step) = sessionState else { return nil }
        guard let exerciseLog = currentExerciseLog else { return nil }

        let startWeight = exerciseLog.startWeight

        switch step {
        case 0:
            return (weight: startWeight * 0.5, reps: 5)
        case 1:
            return (weight: startWeight * 0.7, reps: 3)
        default:
            return nil
        }
    }

    // MARK: - Load Flow

    public func acknowledgeLoad() {
        sessionState = .workingSet
    }

    // MARK: - Working Set Flow

    public func logSet(reps: Int, rating: Rating) {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        let currentWeight = nextPrescription?.weight ?? exerciseLog.startWeight
        let targetReps = nextPrescription?.reps ?? profile.repRange.lowerBound

        let setLog = SetLog(
            setIndex: currentSetIndex + 1,
            targetReps: targetReps,
            targetWeight: currentWeight,
            achievedReps: reps,
            rating: rating,
            actualWeight: currentWeight,
            restPlannedSec: profile.defaultRestSec
        )

        currentExerciseLog?.setLogs.append(setLog)

        // Check for bad-day switch
        if SteelProgressionEngine.shouldActivateBadDaySwitch(setLogs: currentExerciseLog?.setLogs ?? []) {
            applyBadDaySwitch()
        }

        // Compute next prescription using S.T.E.E.L. micro-adjust
        let result = SteelProgressionEngine.microAdjust(
            currentWeight: currentWeight,
            achievedReps: reps,
            repRange: profile.repRange,
            rating: rating,
            baseIncrement: profile.baseIncrement,
            microAdjustStep: profile.microAdjustStep,
            rounding: profile.rounding
        )

        nextPrescription = (reps: result.nextReps, weight: result.nextWeight)

        // Move to rest
        currentSetIndex += 1
        startRestTimer(duration: profile.defaultRestSec)
        persistSession()
    }

    public func advanceToNextSet() {
        // Stop the rest timer
        restTimer?.stop()
        restTimer = nil

        guard let profile = exerciseProfiles[currentExerciseLog?.exerciseId ?? UUID()] else { return }

        if currentSetIndex < profile.sets {
            sessionState = .workingSet
        } else {
            // Exercise complete, compute decision
            finishExercise()
        }
    }

    // MARK: - Timer Management

    private func startRestTimer(duration: Int) {
        // Create new timer
        let timer = RestTimer()
        restTimer = timer

        // Start timer
        timer.start(duration: duration)

        // Initial state
        sessionState = .rest(timeRemaining: duration)

        // Observe timer updates
        timer.$timeRemaining
            .sink { [weak self] remaining in
                self?.sessionState = .rest(timeRemaining: remaining)
            }
            .store(in: &cancellables)
    }

    public func adjustRestTime(by seconds: Int) {
        restTimer?.adjustTime(by: seconds)
    }

    // MARK: - Exercise Completion

    public func finishExercise() {
        guard var exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        // Compute decision
        let decision = SteelProgressionEngine.computeDecision(
            setLogs: exerciseLog.setLogs,
            repRange: profile.repRange,
            totalSets: profile.sets
        )

        exerciseLog.sessionDecision = decision

        // Compute next session start weight
        let recentLoads = getRecentLoads(exerciseId: exerciseLog.exerciseId)
        let result = SteelProgressionEngine.computeNextSessionWeight(
            lastStartLoad: exerciseLog.startWeight,
            decision: decision,
            baseIncrement: profile.baseIncrement,
            rounding: profile.rounding,
            weeklyCapPct: profile.weeklyCapPct,
            recentLoads: recentLoads,
            plateOptions: profile.plateOptions
        )

        exerciseLog.nextStartWeight = result.startWeight

        // Update state
        updateExerciseState(
            exerciseId: exerciseLog.exerciseId,
            startLoad: result.startWeight,
            decision: decision
        )

        // Save to session
        currentExerciseLog = exerciseLog
        currentSession?.exerciseLogs.append(exerciseLog)

        sessionState = .review
    }

    public func advanceToNextExercise() {
        guard let session = currentSession,
              let plan = workoutPlans.first(where: { $0.id == session.workoutPlanId }) else { return }

        currentExerciseIndex += 1

        if currentExerciseIndex < plan.order.count {
            let nextExerciseId = plan.order[currentExerciseIndex]
            startExercise(exerciseId: nextExerciseId)
        } else {
            finishSession()
        }
    }

    // MARK: - Session Completion

    public func finishSession() {
        guard var session = currentSession else { return }

        // Calculate stats
        let totalVolume = session.exerciseLogs.reduce(0.0) { total, log in
            let exerciseVolume = log.setLogs.reduce(0.0) { setTotal, set in
                setTotal + (Double(set.achievedReps) * set.actualWeight)
            }
            return total + exerciseVolume
        }

        session.stats.totalVolume = totalVolume

        // Save session
        currentSession = session
        persistSession()

        sessionState = .done
    }

    // MARK: - Helper Methods

    private func computeInitialPrescription() {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId] else { return }

        nextPrescription = (
            reps: profile.repRange.lowerBound,
            weight: exerciseLog.startWeight
        )
    }

    private func applyBadDaySwitch() {
        guard let exerciseLog = currentExerciseLog,
              let profile = exerciseProfiles[exerciseLog.exerciseId],
              let currentWeight = nextPrescription?.weight else { return }

        let result = SteelProgressionEngine.applyBadDayAdjustment(
            currentWeight: currentWeight,
            baseIncrement: profile.baseIncrement,
            rounding: profile.rounding,
            repRange: profile.repRange
        )

        nextPrescription = (reps: result.nextReps, weight: result.nextWeight)
    }

    private func getRecentLoads(exerciseId: UUID) -> [Double] {
        // Get all sessions from persistence
        let allSessions = PersistenceManager.shared.loadSessions()

        // Calculate date 7 days ago
        let calendar = Calendar.current
        guard let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: Date()) else {
            return []
        }

        // Filter sessions from last 7 days
        let recentSessions = allSessions.filter { session in
            session.date >= sevenDaysAgo
        }

        // Extract start weights for the specific exercise
        let startWeights = recentSessions.compactMap { session -> Double? in
            // Find exercise log for this exercise in the session
            guard let exerciseLog = session.exerciseLogs.first(where: { $0.exerciseId == exerciseId }) else {
                return nil
            }
            return exerciseLog.startWeight
        }

        return startWeights
    }

    private func updateExerciseState(exerciseId: UUID, startLoad: Double, decision: SessionDecision) {
        exerciseStates[exerciseId] = ExerciseState(
            exerciseId: exerciseId,
            lastStartLoad: startLoad,
            lastDecision: decision,
            lastUpdatedAt: Date()
        )
        persistExerciseStates()
    }

    // MARK: - Persistence

    private func persistSession() {
        guard var session = currentSession else { return }

        // Update resume state
        session.currentExerciseIndex = currentExerciseIndex
        session.currentSetIndex = currentSetIndex
        session.sessionStateRaw = serializeSessionState(sessionState)
        session.currentExerciseLog = currentExerciseLog  // Save in-progress exercise log
        session.lastUpdated = Date()

        // Mark as inactive if done
        if case .done = sessionState {
            session.isActive = false
        }

        currentSession = session

        // Save current session
        PersistenceManager.shared.saveCurrentSession(session)

        // Add to history
        var sessions = PersistenceManager.shared.loadSessions()
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        PersistenceManager.shared.saveSessions(sessions)
    }

    private func persistExerciseStates() {
        PersistenceManager.shared.saveExerciseStates(exerciseStates)
    }

    private func loadPersistedState() {
        print("💾 loadPersistedState() called")
        // Load exercise states
        exerciseStates = PersistenceManager.shared.loadExerciseStates()

        // Load profiles (or use defaults if none exist)
        let savedProfiles = PersistenceManager.shared.loadExerciseProfiles()
        print("💾 Loaded \(savedProfiles.count) saved profiles from persistence")
        print("💾 Current exerciseProfiles count before merge: \(exerciseProfiles.count)")
        if !savedProfiles.isEmpty {
            exerciseProfiles = savedProfiles
            print("💾 Replaced exerciseProfiles with saved profiles")
        }
        print("💾 Final exerciseProfiles count: \(exerciseProfiles.count)")

        // Load workout plans
        let savedPlans = PersistenceManager.shared.loadWorkoutPlans()
        if !savedPlans.isEmpty {
            workoutPlans = savedPlans
        }

        // Load current session if exists
        if let savedSession = PersistenceManager.shared.loadCurrentSession() {
            // Check if session is stale
            if PersistenceManager.shared.isSessionStale(savedSession) {
                // Clear stale session
                PersistenceManager.shared.clearCurrentSession()
            } else {
                // Keep session for potential resume
                currentSession = savedSession
            }
        }
    }

    // MARK: - Default Data

    private func loadDefaultExercises() {
        print("📋 loadDefaultExercises() called")
        let benchPress = ExerciseProfile(
            name: "Barbell Bench Press",
            category: .barbell,
            priority: .upper,
            repRange: 5...8,
            sets: 3,
            baseIncrement: 5.0,
            rounding: 2.5,
            microAdjustStep: 2.5,
            weeklyCapPct: 5.0,
            plateOptions: [45, 25, 10, 5, 2.5],
            defaultRestSec: 90
        )

        let squat = ExerciseProfile(
            name: "Barbell Squat",
            category: .barbell,
            priority: .lower,
            repRange: 5...8,
            sets: 4,
            baseIncrement: 10.0,
            rounding: 5.0,
            microAdjustStep: 5.0,
            weeklyCapPct: 10.0,
            plateOptions: [45, 25, 10, 5, 2.5],
            defaultRestSec: 120
        )

        exerciseProfiles[benchPress.id] = benchPress
        exerciseProfiles[squat.id] = squat
        print("📋 Loaded \(exerciseProfiles.count) default exercises")
    }

    private func loadDefaultWorkoutPlan() {
        let exercises = Array(exerciseProfiles.keys)
        let defaultPlan = WorkoutPlan(
            name: "Default Push/Pull",
            order: exercises
        )
        workoutPlans.append(defaultPlan)
    }
}