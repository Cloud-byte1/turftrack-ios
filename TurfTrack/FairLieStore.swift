import Combine
import Foundation

@MainActor
final class FairLieStore: ObservableObject {
    enum Tab: String, CaseIterable { case lab = "Lab", sessions = "Sessions", progress = "Progress" }

    @Published var tab: Tab = .lab
    @Published var club = "7 Iron"
    @Published var swing = SwingResult.zeroed
    @Published var notice = "Start a session, connect GolfMat, then zero and initialize a swing."
    @Published var activeSessionStarted = false
    @Published var sessionClub = "7 Iron"
    @Published var sessionSwings: [SwingResult] = []
    @Published var sessions: [PracticeSession] = PracticeSession.samples
    @Published var selectedSession: PracticeSession?
    @Published var armed = false
    @Published var isZeroed = false
    @Published var calibrating = false
    @Published var packetCount = 0
    @Published var lastReadingAt: Date?
    @Published var tracking = false
    @Published var simBall = 96.0
    @Published var simClub = 72.0
    @Published var simAttack = -5.0
    @Published var simPath = 3.0
    @Published var simQuality = 48.0
    @Published var trackSimLive = true

    let ble = GolfMatBLEManager()
    private var cancellables = Set<AnyCancellable>()

    var liveSession: PracticeSession? {
        guard activeSessionStarted, !sessionSwings.isEmpty else { return nil }
        return buildSessionSummary(sessionSwings, club: sessionClub)
    }

    var profileInitials: String { "CM" }
    var profileName: String { "Carmine" }

    init() {
        ble.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        ble.$lastPacket
            .compactMap { $0 }
            .sink { [weak self] packet in
                self?.acceptLive(packet)
            }
            .store(in: &cancellables)
    }

    func startSession() {
        activeSessionStarted = true
        sessionClub = club
        swing = .zeroed
        armed = false
        isZeroed = false
        lastReadingAt = nil
        packetCount = 0
        sessionSwings = []
        selectedSession = nil
        tab = .lab
        notice = "Session initialized at zero. Connect the mat, then zero the sensors."
    }

    func endSession() {
        guard activeSessionStarted else { return }
        if !sessionSwings.isEmpty {
            let completed = buildSessionSummary(sessionSwings, club: sessionClub, when: "Just now")
            sessions.insert(completed, at: 0)
            selectedSession = completed
        }
        activeSessionStarted = false
        armed = false
        isZeroed = false
        sessionSwings = []
        tab = .sessions
        notice = "Session saved."
    }

    func connectMat() {
        trackSimLive = false
        armed = false
        isZeroed = false
        swing = .zeroed
        notice = "Opening Bluetooth for GolfMat…"
        ble.connect()
        tracking = true
    }

    func disconnectMat() {
        armed = false
        isZeroed = false
        ble.disconnect()
        notice = "Mat disconnected."
    }

    func zeroMat() {
        guard activeSessionStarted else {
            notice = "Initialize a session first."
            return
        }
        calibrating = true
        notice = "Keep the mat still while it zeros…"
        ble.calibrateAndArm()
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            armed = false
            isZeroed = true
            swing = .zeroed
            lastReadingAt = nil
            packetCount = 0
            calibrating = false
            notice = "Sensors are at zero. Initialize the swing when you are ready."
        }
    }

    func initializeSwing() {
        guard activeSessionStarted else {
            notice = "Initialize a session first."
            return
        }
        guard ble.isConnected || tracking else {
            notice = "Connect GolfMat before initializing the swing."
            return
        }
        guard isZeroed else {
            notice = "Zero the sensors before initializing the swing."
            return
        }
        swing = .zeroed
        armed = true
        ble.armed = true
        notice = "Swing initialized — ready for one deliberate strike."
    }

    func clearToZero() {
        calibrating = true
        ble.calibrateAndArm()
        Task {
            try? await Task.sleep(nanoseconds: 400_000_000)
            swing = .zeroed
            armed = false
            isZeroed = true
            sessionSwings = []
            selectedSession = nil
            lastReadingAt = nil
            packetCount = 0
            calibrating = false
            notice = "All readings are zero. Ready for the next swing."
        }
    }

    func demoStrike() {
        guard activeSessionStarted, armed else {
            notice = "Initialize the session, zero it, then initialize the swing first."
            return
        }
        applySwing(SwingSimulator.preset(.random).with(label: "Demo Strike", source: "demo"))
        notice = "Demo strike added to this session."
    }

    func showExample(_ preset: SwingPreset) {
        let next = SwingSimulator.preset(preset)
        applySwing(next, recordIfSession: true)
        notice = "\(next.label) example loaded\(activeSessionStarted ? " and added to this session" : "")."
    }

    func applySimParams(commit: Bool, label: String? = nil) {
        tracking = true
        trackSimLive = true
        let params = SimParams(
            ballMph: simBall,
            clubMph: simClub,
            attack: simAttack,
            path: simPath,
            quality: Int(simQuality),
            zone: 2
        )
        var next = SwingSimulator.simulate(params, label: label ?? "Simulated Swing", commit: commit)
        applySwing(next, recordIfSession: commit)
        if commit { packetCount += 1 }
        lastReadingAt = Date()
    }

    func randomizeSim() {
        let params = SwingSimulator.pickBelowAverage()
        simBall = params.ballMph
        simClub = params.clubMph
        simAttack = params.attack
        simPath = params.path
        simQuality = Double(params.quality)
        applySimParams(commit: false)
        notice = String(
            format: "Randomized below-average swing: %.0f mph ball · %d yds · quality %d",
            swing.ballSpeedMph, swing.carryYards, swing.impactQuality
        )
    }

    func runSimulatedSwing() {
        let params = SwingSimulator.pickBelowAverage()
        simBall = params.ballMph
        simClub = params.clubMph
        simAttack = params.attack
        simPath = params.path
        simQuality = Double(params.quality)
        applySimParams(commit: true, label: "Simulated Swing")
        notice = String(
            format: "Simulated swing: %.0f mph ball · %.1f° attack · %.1f° path · %d yds · Q%d",
            swing.ballSpeedMph, swing.attackAngleDeg, swing.swingPathDeg, swing.carryYards, swing.impactQuality
        )
    }

    func previewSimIfLive() {
        guard trackSimLive else { return }
        applySimParams(commit: false)
    }

    private func acceptLive(_ packet: SwingPacket) {
        trackSimLive = false
        tracking = true
        lastReadingAt = Date()
        packetCount += 1
        let incoming = SwingResult.from(packet: packet)
        if !armed {
            swing = incoming
            notice = "\(incoming.label) tracked — initialize swing to record into a session."
            return
        }
        applySwing(incoming)
        notice = incoming.radarValid
            ? String(format: "Strike captured · radar %.1f mph", incoming.ballSpeedMph)
            : "Strike captured."
    }

    private func applySwing(_ next: SwingResult, recordIfSession: Bool = true) {
        swing = next
        if recordIfSession, !next.preview, activeSessionStarted {
            sessionSwings.append(next)
        }
        if !next.preview { armed = false; ble.armed = false }
    }
}

private extension SwingResult {
    func with(label: String, source: String) -> SwingResult {
        var copy = self
        copy.label = label
        copy.source = source
        return copy
    }
}
