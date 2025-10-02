import SwiftUI

@MainActor
public struct ContentView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var showingAnalytics = false

    public init() {}

    public var body: some View {
        ZStack {
            // Terminal-style background
            Color(red: 0.1, green: 0.15, blue: 0.3)
                .ignoresSafeArea()

            if showingAnalytics {
                // Analytics View
                AnalyticsView(isPresented: $showingAnalytics)
            } else {
                // Main Session Flow
                VStack(spacing: 0) {
                    // Render appropriate view based on session state
                    switch sessionManager.sessionState {
                    case .intro:
                        IntroView(showAnalytics: $showingAnalytics)
                    case .preWorkout:
                        PreWorkoutView()
                    case .stretching(_):
                        StretchingView()
                    case .warmup(_):
                        WarmupView()
                    case .load:
                        LoadView()
                    case .workingSet:
                        WorkingSetView()
                    case .rest(_):
                        RestView()
                    case .review:
                        ReviewView()
                    case .done:
                        DoneView()
                    }
                }
            }
        }
        .font(.system(.body, design: .monospaced))
    }
}

// MARK: - Intro View

@MainActor
struct IntroView: View {
    @Environment(SessionManager.self) private var sessionManager
    @Binding var showAnalytics: Bool
    @State private var showResumePrompt = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Terminal panel
            VStack(alignment: .leading, spacing: 8) {
                Text("INCREMENT")
                    .font(.system(.largeTitle, design: .monospaced))
                    .fontWeight(.bold)

                Text("Terminal-inspired lifting tracker")
                    .font(.system(.body, design: .monospaced))
                    .opacity(0.7)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            Spacer()

            // Resume prompt if there's an active session
            if sessionManager.hasResumableSession {
                VStack(spacing: 12) {
                    Text("Previous session detected")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)

                    HStack(spacing: 12) {
                        Button {
                            sessionManager.resumeSession()
                        } label: {
                            Text("RESUME")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.green.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Button {
                            sessionManager.discardSession()
                        } label: {
                            Text("DISCARD")
                                .font(.system(.body, design: .monospaced))
                                .fontWeight(.bold)
                                .frame(maxWidth: .infinity)
                                .padding(16)
                                .background(Color.red.opacity(0.8))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
            }

            // Dual Action Buttons
            VStack(spacing: 12) {
                // Start Session Button
                ActionBar {
                    // Discard any existing session when starting a new one
                    if sessionManager.hasResumableSession {
                        sessionManager.discardSession()
                    }
                    if let firstPlan = sessionManager.workoutPlans.first {
                        sessionManager.startSession(workoutPlanId: firstPlan.id)
                    }
                } label: {
                    Text(sessionManager.hasResumableSession ? "START NEW WORKOUT" : "START WORKOUT")
                }

                // View Analytics Button
                Button {
                    showAnalytics = true
                } label: {
                    Text("VIEW ANALYTICS")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 24)
            }
        }
        .foregroundColor(.white)
    }
}

// MARK: - Stretching View

@MainActor
struct StretchingView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if case .stretching(let timeRemaining) = sessionManager.sessionState {
                VStack(spacing: 24) {
                    // Header
                    Text("Stretching")
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // Timer
                    VStack(spacing: 8) {
                        Text(formatTime(timeRemaining))
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                            .foregroundColor(.white)

                        Text("Prepare for workout")
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)
                            .foregroundColor(.white)
                    }
                }
                .padding(24)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.finishStretching()
            } label: {
                Text("START WORKOUT →")
            }
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Pre-Workout View

@MainActor
struct PreWorkoutView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var selectedRating: Int = 3
    @State private var feelingNote: String = ""
    @FocusState private var isTextFieldFocused: Bool

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Text("How are you feeling?")
                    .font(.system(.title2, design: .monospaced))
                    .fontWeight(.bold)

                Text("Rate your energy and readiness")
                    .font(.system(.body, design: .monospaced))
                    .opacity(0.7)
            }
            .foregroundColor(.white)

            // Rating scale
            VStack(spacing: 16) {
                HStack(spacing: 12) {
                    ForEach(1...5, id: \.self) { rating in
                        Button {
                            selectedRating = rating
                        } label: {
                            Text("\(rating)")
                                .font(.system(.title, design: .monospaced))
                                .fontWeight(selectedRating == rating ? .bold : .regular)
                                .frame(width: 50, height: 50)
                                .background(
                                    selectedRating == rating
                                        ? Color.white
                                        : Color.white.opacity(0.1)
                                )
                                .foregroundColor(
                                    selectedRating == rating
                                        ? Color(red: 0.1, green: 0.15, blue: 0.3)
                                        : .white
                                )
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Rating labels
                HStack {
                    Text("Low")
                        .font(.system(.caption, design: .monospaced))
                        .opacity(0.5)
                    Spacer()
                    Text("High")
                        .font(.system(.caption, design: .monospaced))
                        .opacity(0.5)
                }
                .foregroundColor(.white)
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .padding(.horizontal, 24)

            // Optional note
            VStack(alignment: .leading, spacing: 8) {
                Text("How do you feel? (optional)")
                    .font(.system(.caption, design: .monospaced))
                    .opacity(0.7)

                TextField("e.g., tired, energized, sore...", text: $feelingNote)
                    .font(.system(.body, design: .monospaced))
                    .padding(12)
                    .background(Color.white.opacity(0.1))
                    .foregroundColor(.white)
                    .cornerRadius(8)
                    .focused($isTextFieldFocused)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)

            Spacer()

            // Action Bar
            ActionBar {
                let feeling = PreWorkoutFeeling(
                    rating: selectedRating,
                    note: feelingNote.isEmpty ? nil : feelingNote
                )
                sessionManager.logPreWorkoutFeeling(feeling)
            } label: {
                Text("START WORKOUT")
            }
        }
        .onTapGesture {
            isTextFieldFocused = false
        }
    }
}

// MARK: - Warmup View

@MainActor
struct WarmupView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        let _ = print("🏋️ WarmupView body called")
        let _ = print("🏋️ currentExerciseLog: \(sessionManager.currentExerciseLog?.exerciseId.uuidString ?? "nil")")
        let _ = print("🏋️ sessionState: \(sessionManager.sessionState)")

        VStack(spacing: 0) {
            // Header
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId] {
                let _ = print("🏋️ Found profile for exercise: \(profile.name)")
                ExerciseHeader(
                    exerciseName: profile.name,
                    setInfo: "Warmup",
                    goal: "\(profile.repRange.lowerBound)–\(profile.repRange.upperBound)",
                    weight: exerciseLog.startWeight,
                    plates: profile.plateOptions.map { plateOptions in
                        SteelProgressionEngine.computePlateBreakdown(
                            exerciseLog.startWeight,
                            plates: plateOptions,
                            barWeight: 45.0
                        )
                    }
                )
            }

            Spacer()

            // Warmup prescription
            if let prescription = sessionManager.getWarmupPrescription() {
                VStack(spacing: 16) {
                    Text("Next warmup:")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)

                    Text("\(prescription.reps) × \(Int(prescription.weight)) lb")
                        .font(.system(.title, design: .monospaced))
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.advanceWarmup()
            } label: {
                Text("NEXT WARMUP WEIGHT »")
            }
        }
    }
}

// MARK: - Load View

@MainActor
struct LoadView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId],
               let prescription = sessionManager.nextPrescription {
                ExerciseHeader(
                    exerciseName: profile.name,
                    setInfo: "Set 1/\(profile.sets)",
                    goal: "\(profile.repRange.lowerBound)–\(profile.repRange.upperBound)",
                    weight: prescription.weight,
                    plates: profile.plateOptions.map { plateOptions in
                        SteelProgressionEngine.computePlateBreakdown(
                            prescription.weight,
                            plates: plateOptions,
                            barWeight: 45.0
                        )
                    }
                )
            }

            Spacer()

            // Plate breakdown
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId],
               let prescription = sessionManager.nextPrescription,
               let plateOptions = profile.plateOptions {
                let plates = SteelProgressionEngine.computePlateBreakdown(
                    prescription.weight,
                    plates: plateOptions,
                    barWeight: 45.0
                )

                VStack(spacing: 12) {
                    Text("Load plates (per side):")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)

                    Text(plates.map { "\(Int($0))" }.joined(separator: " | "))
                        .font(.system(.title2, design: .monospaced))
                        .fontWeight(.bold)
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.acknowledgeLoad()
            } label: {
                Text("LOAD PLATES")
            }
        }
    }
}

// MARK: - Working Set View

@MainActor
struct WorkingSetView: View {
    @Environment(SessionManager.self) private var sessionManager
    @State private var reps: Int = 5

    var body: some View {
        VStack(spacing: 0) {
            // Header
            if let exerciseLog = sessionManager.currentExerciseLog,
               let profile = sessionManager.exerciseProfiles[exerciseLog.exerciseId],
               let prescription = sessionManager.nextPrescription {
                ExerciseHeader(
                    exerciseName: profile.name,
                    setInfo: "Set \(sessionManager.currentSetIndex + 1)/\(profile.sets)",
                    goal: "\(profile.repRange.lowerBound)–\(profile.repRange.upperBound)",
                    weight: prescription.weight,
                    plates: profile.plateOptions.map { plateOptions in
                        SteelProgressionEngine.computePlateBreakdown(
                            prescription.weight,
                            plates: plateOptions,
                            barWeight: 45.0
                        )
                    }
                )

                // Content panel
                VStack(spacing: 24) {
                    // Reps input
                    HStack {
                        Text("Reps:")
                            .font(.system(.body, design: .monospaced))

                        Stepper("\(reps)", value: $reps, in: 0...20)
                            .font(.system(.title2, design: .monospaced))
                            .fontWeight(.bold)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )

                    // Rating buttons (SRCL Action List)
                    VStack(spacing: 12) {
                        ForEach(Rating.allCases, id: \.self) { rating in
                            Button {
                                sessionManager.logSet(reps: reps, rating: rating)
                            } label: {
                                Text(rating.rawValue)
                                    .font(.system(.body, design: .monospaced))
                                    .fontWeight(.bold)
                                    .frame(maxWidth: .infinity)
                                    .padding(16)
                                    .background(ratingColor(rating))
                                    .foregroundColor(.white)
                                    .cornerRadius(8)
                            }
                        }
                    }
                }
                .padding(24)
            }

            Spacer()
        }
        .foregroundColor(.white)
        .onAppear {
            if let prescription = sessionManager.nextPrescription {
                reps = prescription.reps
            }
        }
    }

    private func ratingColor(_ rating: Rating) -> Color {
        switch rating {
        case .fail:
            return Color.red.opacity(0.8)
        case .holyShit:
            return Color.orange.opacity(0.8)
        case .hard:
            return Color.blue.opacity(0.8)
        case .easy:
            return Color.green.opacity(0.8)
        }
    }
}

// MARK: - Rest View

@MainActor
struct RestView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let prescription = sessionManager.nextPrescription,
               case .rest(let timeRemaining) = sessionManager.sessionState {
                VStack(spacing: 24) {
                    // Next prescription
                    VStack(spacing: 8) {
                        Text("Next:")
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)

                        Text("\(prescription.reps) × \(Int(prescription.weight)) lb")
                            .font(.system(.title, design: .monospaced))
                            .fontWeight(.bold)
                    }

                    // Rest timer
                    VStack(spacing: 8) {
                        Text("Rest:")
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)

                        Text(formatTime(timeRemaining))
                            .font(.system(.largeTitle, design: .monospaced))
                            .fontWeight(.bold)
                    }
                }
                .foregroundColor(.white)
            }

            Spacer()

            // Action Bar with two controls
            HStack(spacing: 16) {
                Button {
                    sessionManager.adjustRestTime(by: -10)
                } label: {
                    Text("-10s")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white.opacity(0.1))
                        .foregroundColor(.white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)

                Button {
                    sessionManager.advanceToNextSet()
                } label: {
                    Text("NEXT →")
                        .font(.system(.body, design: .monospaced))
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .background(Color.white)
                        .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.3))
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
        }
    }

    private func formatTime(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%02d:%02d", mins, secs)
    }
}

// MARK: - Review View

@MainActor
struct ReviewView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            if let exerciseLog = sessionManager.currentExerciseLog,
               let decision = exerciseLog.sessionDecision {
                VStack(spacing: 24) {
                    // Decision badge
                    VStack(spacing: 12) {
                        DecisionBadge(decision: decision)

                        Text(decisionReason(decision))
                            .font(.system(.body, design: .monospaced))
                            .opacity(0.7)
                            .multilineTextAlignment(.center)
                    }
                }
                .foregroundColor(.white)
                .padding(24)
            }

            Spacer()

            // Action Bar
            ActionBar {
                sessionManager.advanceToNextExercise()
            } label: {
                Text(nextButtonLabel())
            }
        }
    }

    private func nextButtonLabel() -> String {
        guard let session = sessionManager.currentSession,
              let plan = sessionManager.workoutPlans.first(where: { $0.id == session.workoutPlanId }) else {
            return "NEXT EXERCISE"
        }

        if sessionManager.currentExerciseIndex < plan.order.count - 1 {
            return "NEXT EXERCISE"
        } else {
            return "END SESSION"
        }
    }

    private func decisionReason(_ decision: SessionDecision) -> String {
        switch decision {
        case .up_2:
            return "All sets at top range, felt easy"
        case .up_1:
            return "Hit targets, no failures"
        case .down_1:
            return "Multiple red sets or missed targets"
        case .hold:
            return "Maintaining current load"
        }
    }
}

// MARK: - Done View

@MainActor
struct DoneView: View {
    @Environment(SessionManager.self) private var sessionManager

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 16) {
                Text("Session Complete")
                    .font(.system(.title, design: .monospaced))
                    .fontWeight(.bold)

                if let session = sessionManager.currentSession {
                    Text("Total Volume: \(Int(session.stats.totalVolume)) lb")
                        .font(.system(.body, design: .monospaced))
                        .opacity(0.7)
                }
            }
            .foregroundColor(.white)

            Spacer()

            ActionBar {
                sessionManager.sessionState = .intro
            } label: {
                Text("BACK TO START")
            }
        }
    }
}

// MARK: - Reusable Components

struct ExerciseHeader: View {
    let exerciseName: String
    let setInfo: String
    let goal: String
    let weight: Double
    let plates: [Double]?

    var body: some View {
        HStack(alignment: .top) {
            // Left: Exercise name
            Text(exerciseName)
                .font(.system(.title3, design: .monospaced))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Right: Stats column
            VStack(alignment: .trailing, spacing: 4) {
                Text("Set: \(setInfo)")
                Text("Goal: \(goal)")
                Text("Weight: \(Int(weight)) lb")

                if let plates = plates {
                    Text("Plates: \(plates.map { "\(Int($0))" }.joined(separator: " | "))")
                        .font(.system(.caption, design: .monospaced))
                }
            }
            .font(.system(.caption, design: .monospaced))
        }
        .foregroundColor(.white)
        .padding(16)
        .background(Color.black.opacity(0.3))
    }
}

struct ActionBar<Label: View>: View {
    let action: () -> Void
    let label: () -> Label

    var body: some View {
        Button(action: action) {
            label()
                .font(.system(.body, design: .monospaced))
                .fontWeight(.bold)
                .frame(maxWidth: .infinity)
                .padding(16)
                .background(Color.white)
                .foregroundColor(Color(red: 0.1, green: 0.15, blue: 0.3))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .padding(24)
    }
}

struct DecisionBadge: View {
    let decision: SessionDecision

    var body: some View {
        HStack(spacing: 8) {
            Text(badgeText(decision))
                .font(.system(.title2, design: .monospaced))
                .fontWeight(.bold)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(badgeColor(decision))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    private func badgeText(_ decision: SessionDecision) -> String {
        switch decision {
        case .up_2:
            return "UP ++"
        case .up_1:
            return "UP +"
        case .down_1:
            return "DOWN -"
        case .hold:
            return "HOLD"
        }
    }

    private func badgeColor(_ decision: SessionDecision) -> Color {
        switch decision {
        case .up_2, .up_1:
            return Color.green.opacity(0.8)
        case .down_1:
            return Color.red.opacity(0.8)
        case .hold:
            return Color.blue.opacity(0.8)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environment(SessionManager())
    }
}