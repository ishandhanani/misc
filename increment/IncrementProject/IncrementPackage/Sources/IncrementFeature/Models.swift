import Foundation

// MARK: - Enums

public enum ExerciseCategory: String, Codable, Sendable {
    case barbell
    case dumbbell
    case machine
    case bodyweight
}

public enum ExercisePriority: String, Codable, Sendable {
    case upper
    case lower
    case accessory
}

public enum Rating: String, Codable, Sendable, CaseIterable {
    case fail = "FAIL"
    case holyShit = "HOLY_SHIT"
    case hard = "HARD"
    case easy = "EASY"
}

public enum SessionDecision: String, Codable, Sendable {
    case up_2
    case up_1
    case hold
    case down_1
}

// MARK: - ExerciseProfile

public struct ExerciseProfile: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let category: ExerciseCategory
    public let priority: ExercisePriority
    public let repRange: ClosedRange<Int>
    public let sets: Int
    public let baseIncrement: Double  // Total load step
    public let rounding: Double
    public let microAdjustStep: Double?
    public let weeklyCapPct: Double  // 5-10%
    public let plateOptions: [Double]?  // Per-side plates for barbells
    public let warmupRule: String  // "ramped_2" for 50%×5 → 70%×3
    public let defaultRestSec: Int

    public init(
        id: UUID = UUID(),
        name: String,
        category: ExerciseCategory,
        priority: ExercisePriority,
        repRange: ClosedRange<Int>,
        sets: Int,
        baseIncrement: Double,
        rounding: Double,
        microAdjustStep: Double? = nil,
        weeklyCapPct: Double,
        plateOptions: [Double]? = nil,
        warmupRule: String = "ramped_2",
        defaultRestSec: Int
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.priority = priority
        self.repRange = repRange
        self.sets = sets
        self.baseIncrement = baseIncrement
        self.rounding = rounding
        self.microAdjustStep = microAdjustStep
        self.weeklyCapPct = weeklyCapPct
        self.plateOptions = plateOptions
        self.warmupRule = warmupRule
        self.defaultRestSec = defaultRestSec
    }
}

// MARK: - ExerciseState

public struct ExerciseState: Codable, Sendable {
    public let exerciseId: UUID
    public var lastStartLoad: Double
    public var lastDecision: SessionDecision?
    public var lastUpdatedAt: Date
}

// MARK: - SetLog

public struct SetLog: Codable, Identifiable, Sendable {
    public let id: UUID
    public let setIndex: Int
    public let targetReps: Int
    public let targetWeight: Double
    public var achievedReps: Int
    public var rating: Rating
    public let actualWeight: Double
    public var restPlannedSec: Int?

    public init(
        id: UUID = UUID(),
        setIndex: Int,
        targetReps: Int,
        targetWeight: Double,
        achievedReps: Int,
        rating: Rating,
        actualWeight: Double,
        restPlannedSec: Int? = nil
    ) {
        self.id = id
        self.setIndex = setIndex
        self.targetReps = targetReps
        self.targetWeight = targetWeight
        self.achievedReps = achievedReps
        self.rating = rating
        self.actualWeight = actualWeight
        self.restPlannedSec = restPlannedSec
    }
}

// MARK: - ExerciseSessionLog

public struct ExerciseSessionLog: Codable, Identifiable, Sendable {
    public let id: UUID
    public let exerciseId: UUID
    public let startWeight: Double
    public var setLogs: [SetLog]
    public var sessionDecision: SessionDecision?
    public var nextStartWeight: Double?

    public init(
        id: UUID = UUID(),
        exerciseId: UUID,
        startWeight: Double,
        setLogs: [SetLog] = [],
        sessionDecision: SessionDecision? = nil,
        nextStartWeight: Double? = nil
    ) {
        self.id = id
        self.exerciseId = exerciseId
        self.startWeight = startWeight
        self.setLogs = setLogs
        self.sessionDecision = sessionDecision
        self.nextStartWeight = nextStartWeight
    }
}

// MARK: - PreWorkoutFeeling

public struct PreWorkoutFeeling: Codable, Sendable {
    public let rating: Int  // 1-5
    public let note: String?  // Optional text description

    public init(rating: Int, note: String? = nil) {
        self.rating = rating
        self.note = note
    }
}

// MARK: - Session

public struct Session: Codable, Identifiable, Sendable {
    public let id: UUID
    public let date: Date
    public let workoutPlanId: UUID
    public var preWorkoutFeeling: PreWorkoutFeeling?
    public var exerciseLogs: [ExerciseSessionLog]
    public var stats: SessionStats
    public var synced: Bool

    // Resume state fields
    public var isActive: Bool
    public var currentExerciseIndex: Int?
    public var currentSetIndex: Int?
    public var sessionStateRaw: String?  // Serialized SessionState
    public var currentExerciseLog: ExerciseSessionLog?  // In-progress exercise log
    public var lastUpdated: Date

    public init(
        id: UUID = UUID(),
        date: Date = Date(),
        workoutPlanId: UUID,
        preWorkoutFeeling: PreWorkoutFeeling? = nil,
        exerciseLogs: [ExerciseSessionLog] = [],
        stats: SessionStats = SessionStats(totalVolume: 0),
        synced: Bool = false,
        isActive: Bool = true,
        currentExerciseIndex: Int? = nil,
        currentSetIndex: Int? = nil,
        sessionStateRaw: String? = nil,
        currentExerciseLog: ExerciseSessionLog? = nil,
        lastUpdated: Date = Date()
    ) {
        self.id = id
        self.date = date
        self.workoutPlanId = workoutPlanId
        self.preWorkoutFeeling = preWorkoutFeeling
        self.exerciseLogs = exerciseLogs
        self.stats = stats
        self.synced = synced
        self.isActive = isActive
        self.currentExerciseIndex = currentExerciseIndex
        self.currentSetIndex = currentSetIndex
        self.sessionStateRaw = sessionStateRaw
        self.currentExerciseLog = currentExerciseLog
        self.lastUpdated = lastUpdated
    }
}

public struct SessionStats: Codable, Sendable {
    public var totalVolume: Double

    public init(totalVolume: Double) {
        self.totalVolume = totalVolume
    }
}

// MARK: - WorkoutPlan

public struct WorkoutPlan: Codable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let order: [UUID]  // exerciseIds in order

    public init(id: UUID = UUID(), name: String, order: [UUID]) {
        self.id = id
        self.name = name
        self.order = order
    }
}

// MARK: - Codable Extensions for ClosedRange
// Note: ClosedRange is already Codable in Swift 6.0+, so this extension is not needed