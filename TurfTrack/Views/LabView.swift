import SwiftUI

struct LabView: View {
    @EnvironmentObject private var store: FairLieStore
    @EnvironmentObject private var auth: AuthStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                topBar
                welcome
                if store.activeSessionStarted { activeSessionCard }
                deviceDocks
                if let error = store.ble.errorMessage {
                    Text(error).font(.caption).foregroundStyle(Theme.danger)
                } else {
                    Text(store.notice).font(.caption).foregroundStyle(Theme.muted)
                }
                radarPanel
                simPanel
                workflow
                liveMonitor
                heroGrid
                pathPanel
                gradePanel
                examples
                impactCoach
            }
            .padding(.horizontal, 18)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .background(Theme.cream)
        .onChange(of: store.simBall, perform: { _ in store.previewSimIfLive() })
        .onChange(of: store.simClub, perform: { _ in store.previewSimIfLive() })
        .onChange(of: store.simAttack, perform: { _ in store.previewSimIfLive() })
        .onChange(of: store.simPath, perform: { _ in store.previewSimIfLive() })
        .onChange(of: store.simQuality, perform: { _ in store.previewSimIfLive() })
    }

    private var topBar: some View {
        HStack {
            HStack(spacing: 10) {
                ZStack {
                    Circle().fill(Theme.green)
                    Image(systemName: "flag.fill").foregroundStyle(.white)
                }
                .frame(width: 38, height: 38)
                Text("fairLie").font(.headline.weight(.heavy)).tracking(1.2).foregroundStyle(Theme.greenDark)
            }
            Spacer()
            HStack(spacing: 10) {
                Circle()
                    .fill(Theme.profile)
                    .frame(width: 42, height: 42)
                    .overlay(Text(store.profileInitials).font(.subheadline.weight(.bold)))
                    .overlay(Circle().stroke(.white, lineWidth: 3))
                VStack(alignment: .leading, spacing: 1) {
                    Text(auth.user.name).font(.subheadline.weight(.semibold))
                    Text("12 day streak").font(.caption2).foregroundStyle(Theme.muted)
                }
            }
        }
        .padding(.top, 8)
    }

    private var welcome: some View {
        HStack(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 6) {
                Text(Date.now.formatted(.dateTime.weekday(.wide).month(.wide).day()).uppercased())
                    .eyebrowStyle()
                Text("Good afternoon, \(auth.user.name).")
                    .font(.system(size: 28, weight: .bold))
                    .foregroundStyle(Theme.ink)
                Text("Ready to dial in your next shot?")
                    .foregroundStyle(Theme.muted)
            }
            Spacer()
            Button {
                store.activeSessionStarted ? store.endSession() : store.startSession()
            } label: {
                Label(store.activeSessionStarted ? "End session" : "Start new session",
                      systemImage: store.activeSessionStarted ? "stop.fill" : "plus")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .padding(.vertical, 14)
                    .background(store.activeSessionStarted ? Theme.danger : Theme.green, in: Capsule())
            }
        }
        .padding(.top, 12)
    }

    private var activeSessionCard: some View {
        let live = store.liveSession
        return HStack {
            Circle().fill(Color(red: 0.49, green: 0.94, blue: 0.67)).frame(width: 11, height: 11)
            VStack(alignment: .leading, spacing: 2) {
                Text("SESSION IN PROGRESS").eyebrowStyle().foregroundStyle(.white.opacity(0.55))
                Text("\(store.sessionClub) practice").font(.headline).foregroundStyle(.white)
            }
            Spacer()
            sessionStat("\(store.sessionSwings.count)", "swings")
            sessionStat(live.map { "\($0.score)" } ?? "—", "avg")
            sessionStat(live.map { "\($0.bestCarryYds)" } ?? "—", "best yds")
            Button("Finish & save") { store.endSession() }
                .font(.caption.weight(.bold))
                .foregroundStyle(Theme.greenDark)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.white, in: Capsule())
        }
        .padding(18)
        .background(Theme.greenDark, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
    }

    private func sessionStat(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundStyle(.white)
            Text(label).font(.caption2).foregroundStyle(.white.opacity(0.58))
        }
        .padding(.trailing, 6)
    }

    private var deviceDocks: some View {
        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                Circle()
                    .fill(store.armed ? Theme.green : Color(white: 0.8))
                    .frame(width: 14, height: 14)
                VStack(alignment: .leading, spacing: 3) {
                    Text("MAT ESP · FSR / SWING").eyebrowStyle()
                    Text(matTitle).font(.subheadline.weight(.bold))
                    Text(store.ble.isConnected ? "Bluetooth mat linked" : "Connect GolfMat over BLE")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
                FlowButtons {
                    if !store.ble.isConnected {
                        pill("Mat BLE", enabled: store.ble.connectionState != .scanning) { store.connectMat() }
                    } else {
                        pill(store.calibrating ? "Zeroing…" : store.isZeroed ? "Re-zero" : "Zero sensors",
                             emphasized: true,
                             enabled: store.activeSessionStarted && !store.calibrating) { store.zeroMat() }
                        pill(store.armed ? "Armed" : "Initialize swing",
                             dark: true,
                             enabled: store.activeSessionStarted && store.isZeroed && !store.armed) { store.initializeSwing() }
                        pill("Disconnect") { store.disconnectMat() }
                    }
                    pill("Clear to zero", enabled: store.activeSessionStarted && store.ble.isConnected && !store.calibrating) {
                        store.clearToZero()
                    }
                    pill("Test swing", demo: true, enabled: store.activeSessionStarted && store.armed) {
                        store.demoStrike()
                    }
                }
            }
            .padding(18)
            .background(store.armed ? Color(red: 0.91, green: 0.96, blue: 0.93) : .white, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: Theme.cardShadow, radius: 16, y: 8)

            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text("RADAR ESP · XM125").eyebrowStyle()
                    Text(store.swing.radarValid ? "Radar values from mat packet / sim" : "Connect radar ESP")
                        .font(.subheadline.weight(.bold))
                    Text("On iPhone, ball speed arrives in the GolfMat BLE packet when the radar ESP is wired to the mat.")
                        .font(.caption)
                        .foregroundStyle(Theme.muted)
                }
                Spacer()
            }
            .padding(18)
            .background(store.swing.radarValid ? Theme.greenDeep : .white, in: RoundedRectangle(cornerRadius: 22))
            .foregroundStyle(store.swing.radarValid ? .white : Theme.ink)
            .shadow(color: Theme.cardShadow, radius: 16, y: 8)
        }
    }

    private var matTitle: String {
        if store.armed { return "Ready for one swing" }
        if !store.activeSessionStarted { return "Initialize a session" }
        if !store.ble.isConnected { return "Connect mat ESP" }
        if !store.isZeroed { return "Mat linked · Needs zeroing" }
        return "Zeroed · Initialize swing"
    }

    private var radarPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("XM125 RADAR · SEPARATE ESP").eyebrowStyle().foregroundStyle(store.swing.radarValid ? .white.opacity(0.55) : Theme.eyebrow)
            Text(store.swing.radarValid ? "Radar motion locked" : "Radar values from mat packet / sim")
                .font(.headline)
            Text(
                store.swing.radarValid
                    ? String(format: "Live %.1f mph · dist %@ mm · intra %@",
                             store.swing.ballSpeedMph,
                             store.swing.radarDistanceMm.map(String.init) ?? "—",
                             store.swing.radarIntraScore.map(String.init) ?? "—")
                    : "Mat BLE carries radar fields when the second ESP is attached. USB radar is available in the web lab."
            )
            .font(.caption)
            .foregroundStyle(store.swing.radarValid ? .white.opacity(0.72) : Theme.muted)
            if store.swing.radarValid {
                HStack {
                    radarStat(String(format: "%.1f", store.swing.ballSpeedMph), "mph")
                    radarStat(store.swing.radarDistanceMm.map(String.init) ?? "—", "mm")
                    radarStat(store.swing.radarIntraScore.map(String.init) ?? "—", "intra")
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .foregroundStyle(store.swing.radarValid ? .white : Theme.ink)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(store.swing.radarValid ? Theme.greenDeep : Theme.paper)
        )
        .shadow(color: Theme.cardShadow, radius: 16, y: 8)
    }

    private func radarStat(_ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.title3.weight(.bold))
            Text(unit.uppercased()).font(.caption2).opacity(0.55)
        }
        .padding(10)
        .background(.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
    }

    private var simPanel: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("SWING SIMULATOR").eyebrowStyle()
                    Text("Below-average mid-handicap swings").font(.headline)
                    Text(store.trackSimLive
                         ? "Live track on — Randomize / Simulate picks a new missy swing each time."
                         : "Randomize for a fresh below-average strike, or nudge the sliders.")
                    .font(.caption)
                    .foregroundStyle(Theme.muted)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 8) {
                    Toggle("Live track", isOn: $store.trackSimLive).labelsHidden()
                    HStack {
                        Button("Randomize") { store.randomizeSim() }
                            .buttonStyle(SoftPill())
                        Button("Simulate swing") { store.runSimulatedSwing() }
                            .buttonStyle(GreenPill())
                    }
                }
            }
            VStack(spacing: 10) {
                simSlider("Ball speed", value: $store.simBall, range: 50...180, format: "%.0f mph")
                simSlider("Club speed", value: $store.simClub, range: 40...130, format: "%.0f mph")
                simSlider("Attack angle", value: $store.simAttack, range: -12...8, format: "%.1f°")
                simSlider("Swing path", value: $store.simPath, range: -12...12, format: "%.1f°")
                simSlider("Impact quality", value: $store.simQuality, range: 20...100, format: "%.0f")
            }
        }
        .padding(20)
        .fairCard()
    }

    private func simSlider(_ title: String, value: Binding<Double>, range: ClosedRange<Double>, format: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title).font(.caption.weight(.semibold)).foregroundStyle(Theme.muted)
                Spacer()
                Text(String(format: format, value.wrappedValue)).font(.caption.weight(.bold)).foregroundStyle(Theme.greenDark)
            }
            Slider(value: value, in: range)
                .tint(Theme.green)
        }
        .padding(12)
        .background(Color(red: 0.96, green: 0.97, blue: 0.96), in: RoundedRectangle(cornerRadius: 16))
    }

    private var workflow: some View {
        let steps: [(String, Bool, Bool)] = [
            ("Session", store.activeSessionStarted, !store.activeSessionStarted),
            ("Connect", store.ble.isConnected || store.tracking, store.activeSessionStarted && !store.ble.isConnected),
            ("Zero", store.isZeroed, store.ble.isConnected && !store.isZeroed),
            ("Initialize", store.armed, store.isZeroed && !store.armed),
            ("Strike", false, store.armed),
        ]
        return HStack(spacing: 6) {
            ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                HStack(spacing: 6) {
                    Text(step.1 ? "✓" : "\(index + 1)")
                        .font(.caption2.weight(.bold))
                        .frame(width: 22, height: 22)
                        .background(step.1 || step.2 ? Theme.green : Color(white: 0.93), in: Circle())
                        .foregroundStyle(step.1 || step.2 ? .white : Theme.muted)
                    Text(step.0).font(.caption2.weight(.bold)).foregroundStyle(step.1 || step.2 ? Theme.greenDark : Theme.muted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(step.2 ? Color(red: 0.91, green: 0.96, blue: 0.93) : .clear, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(12)
        .fairCard()
    }

    private var liveMonitor: some View {
        let values = store.swing.fsrPeaks
        let peak = values.max() ?? 0
        let peakIndex = peak > 0 ? (values.firstIndex(of: peak) ?? -1) + 1 : 0
        return HStack(spacing: 16) {
            Circle()
                .fill(store.ble.isConnected || store.tracking ? Color(red: 0.33, green: 0.89, blue: 0.55) : Color(white: 0.4))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 2) {
                Text("LIVE READINGS").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.white.opacity(0.4))
                Text(store.ble.isConnected ? "Mat BLE · tracking" : store.tracking ? "Simulator · tracking" : "Waiting for a device")
                    .font(.subheadline.weight(.bold)).foregroundStyle(.white)
                Text(store.lastReadingAt.map { "Last update \($0.formatted(date: .omitted, time: .standard)) · \(store.packetCount) packets" } ?? "Connect GolfMat or use the simulator")
                    .font(.caption2).foregroundStyle(.white.opacity(0.45))
            }
            HStack(spacing: 6) {
                ForEach(0..<6, id: \.self) { index in
                    let value = index < values.count ? values[index] : 0
                    VStack(spacing: 4) {
                        Text("S\(index + 1)").font(.system(size: 8, weight: .heavy)).foregroundStyle(.white.opacity(0.42))
                        GeometryReader { geo in
                            Capsule().fill(.white.opacity(0.1)).overlay(alignment: .leading) {
                                Capsule().fill(LinearGradient(colors: [Color(red: 0.33, green: 0.89, blue: 0.55), Theme.gold], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: geo.size.width * min(1, CGFloat(value) / 180))
                            }
                        }
                        .frame(height: 4)
                        Text("\(value)").font(.caption.weight(.bold)).foregroundStyle(.white)
                    }
                    .padding(8)
                    .background(index + 1 == peakIndex ? Color(red: 0.33, green: 0.89, blue: 0.55).opacity(0.12) : .white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11))
                }
            }
        }
        .padding(18)
        .background(Color(red: 0.09, green: 0.13, blue: 0.11), in: RoundedRectangle(cornerRadius: 22))
    }

    private var heroGrid: some View {
        let swing = store.swing
        let score = swing.impactQuality
        return VStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Label(store.tracking ? "TRACKING" : "STRIKE LAB", systemImage: "circle.fill")
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.white.opacity(0.12), in: Capsule())
                    Spacer()
                }
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("LAST STRIKE").font(.caption2.weight(.bold)).tracking(1.4).foregroundStyle(.white.opacity(0.6))
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            Text("\(swing.carryYards)").font(.system(size: 64, weight: .heavy)).foregroundStyle(.white)
                            Text("yds").font(.title3).foregroundStyle(.white.opacity(0.65))
                        }
                        Text(score >= 85 ? "Pure contact." : score >= 60 ? "Solid strike." : swing.isZeroed ? "Waiting." : "Keep working.")
                            .font(.title3.weight(.bold)).foregroundStyle(.white)
                        Text("\(swing.impactName) · \(swing.directionLabel) · \(Int(swing.ballSpeedMph.rounded())) mph ball")
                            .font(.caption).foregroundStyle(.white.opacity(0.62))
                    }
                    Spacer()
                    ShotGraphic().frame(width: 140, height: 120)
                }
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                    metric("Club speed", "\(Int(swing.clubSpeedMph.rounded()))", "mph")
                    metric("Ball speed", "\(Int(swing.ballSpeedMph.rounded()))", "mph")
                    metric("Smash", swing.smash.map { String(format: "%.2f", $0) } ?? "—", "x")
                    metric("Attack", String(format: "%.1f", swing.attackAngleDeg), "°")
                    metric("Path", String(format: "%.1f", swing.swingPathDeg), "°")
                    metric("Radar", swing.radarValid ? "On" : "—", "")
                }
            }
            .padding(24)
            .background(
                LinearGradient(colors: [Theme.greenDark, Color(red: 0.07, green: 0.46, blue: 0.28)], startPoint: .topLeading, endPoint: .bottomTrailing),
                in: RoundedRectangle(cornerRadius: 28)
            )

            VStack(spacing: 12) {
                HStack {
                    Text("STRIKE SUMMARY").font(.caption.weight(.bold)).foregroundStyle(Theme.muted)
                    Spacer()
                    Text(score >= 85 ? "Pure" : score >= 60 ? "Solid" : "Work").font(.caption.weight(.bold)).foregroundStyle(Theme.green)
                }
                ZStack {
                    Circle().stroke(Color(red: 0.91, green: 0.96, blue: 0.93), lineWidth: 12)
                    Circle()
                        .trim(from: 0, to: CGFloat(score) / 100)
                        .stroke(Theme.green, style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack {
                        Text("\(score)").font(.system(size: 36, weight: .heavy))
                        Text(score >= 85 ? "Excellent" : score >= 60 ? "Good" : "Building").font(.caption).foregroundStyle(Theme.muted)
                    }
                }
                .frame(width: 140, height: 140)
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    summary("\(swing.carryYards)", "carry yds")
                    summary("\(Int(swing.ballSpeedMph.rounded()))", "ball mph")
                    summary("\(Int(swing.clubSpeedMph.rounded()))", "club mph")
                    summary(swing.smash.map { String(format: "%.2f", $0) } ?? "—", "smash")
                    summary(String(format: "%.1f°", swing.attackAngleDeg), "attack")
                    summary(String(format: "%.1f°", swing.swingPathDeg), "path")
                    summary("\(swing.heelPressurePct)/\(swing.centerPressurePct)/\(swing.toePressurePct)", "H/C/T")
                    summary(swing.radarValid ? "\(Int(swing.ballSpeedMph.rounded()))" : "—", "radar mph")
                }
            }
            .padding(20)
            .fairCard()
        }
    }

    private func metric(_ label: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label).font(.caption).foregroundStyle(.white.opacity(0.55))
            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Text(value).font(.headline).foregroundStyle(.white)
                Text(unit).font(.caption).foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.09), in: RoundedRectangle(cornerRadius: 16))
    }

    private func summary(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(.headline).foregroundStyle(Theme.greenDark)
            Text(label).font(.caption2).foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pathPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("3D SWING PATH").eyebrowStyle()
                    Text("Tracked club-head arc").font(.headline)
                }
                Spacer()
                Text(store.tracking ? "● Live tracking" : "Idle")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(store.tracking ? Theme.green : Theme.muted)
            }
            SwingPathView(points: store.swing.pathPoints, quality: store.swing.impactQuality)
                .frame(height: 240)
        }
        .padding(18)
        .fairCard()
    }

    private var gradePanel: some View {
        let zero = store.swing.isZeroed
        let contact = zero ? 0 : store.swing.impactQuality
        let path = zero ? 0 : max(0, Int((100 - abs(store.swing.swingPathDeg) * 9).rounded()))
        let attack = zero ? 0 : max(0, Int((100 - abs(store.swing.attackAngleDeg + 3) * 12).rounded()))
        let overall = zero ? 0 : Int((Double(contact) * 0.55 + Double(path) * 0.25 + Double(attack) * 0.2).rounded())
        let items = [
            ("Overall", overall, zero ? "Waiting" : "Combined strike grade"),
            ("Contact", contact, "Impact quality"),
            ("Swing path", path, String(format: "%.1f° path", store.swing.swingPathDeg)),
            ("Attack", attack, String(format: "%.1f° angle", store.swing.attackAngleDeg)),
        ]
        return VStack(alignment: .leading, spacing: 14) {
            Text("STRIKE GRADES").eyebrowStyle()
            Text(zero ? "Take a swing to grade it" : "Your swing report").font(.headline)
            ForEach(items, id: \.0) { item in
                HStack {
                    Text(zero ? "—" : LetterGrade.from(score: item.1).rawValue)
                        .font(.title.weight(.black))
                        .foregroundStyle(Color(hex: LetterGrade.from(score: item.1).color))
                        .frame(width: 44)
                    VStack(alignment: .leading) {
                        Text(item.0).font(.subheadline.weight(.bold))
                        Text(item.2).font(.caption).foregroundStyle(Theme.muted)
                    }
                    Spacer()
                    Text("\(item.1)").font(.title3.weight(.bold).monospacedDigit())
                }
                .padding(.vertical, 6)
            }
        }
        .padding(20)
        .fairCard()
    }

    private var examples: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("COMPARE CONTACT").eyebrowStyle()
            Text("What different swings look like").font(.headline)
            Text("Select one to update every reading and the heat map.")
                .font(.caption).foregroundStyle(Theme.muted)
            HStack(spacing: 8) {
                ForEach(SwingPreset.allCases) { preset in
                    Button {
                        store.showExample(preset)
                    } label: {
                        VStack(spacing: 4) {
                            Text(preset.mark)
                            Text(preset.title).font(.caption.weight(.bold))
                            Text(preset.note).font(.caption2).foregroundStyle(Theme.muted).lineLimit(1)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(store.swing.label.lowercased().contains(preset.title.lowercased()) ? Color(red: 0.91, green: 0.96, blue: 0.93) : Color(white: 0.96), in: RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(Theme.ink)
                }
            }
        }
        .padding(20)
        .fairCard()
    }

    private var impactCoach: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("IMPACT ANALYSIS").eyebrowStyle()
                    Text("Where you struck it").font(.headline)
                }
                Spacer()
                HStack(spacing: 0) {
                    ForEach(["Driver", "7 Iron", "PW"], id: \.self) { item in
                        Button(item) { store.club = item }
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .background(store.club == item ? .white : .clear, in: Capsule())
                            .foregroundStyle(store.club == item ? Theme.greenDark : Theme.muted)
                    }
                }
                .padding(4)
                .background(Color(white: 0.94), in: Capsule())
            }
            PressureHeatmapView(swing: store.swing, live: store.armed || store.tracking)
            HStack {
                Text("✓").font(.title2).foregroundStyle(Theme.green)
                VStack(alignment: .leading) {
                    Text(store.swing.impactName).font(.subheadline.weight(.bold))
                    Text("\(store.swing.heelPressurePct)% heel · \(store.swing.centerPressurePct)% center · \(store.swing.toePressurePct)% toe")
                        .font(.caption).foregroundStyle(Theme.muted)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                Text("COACH'S NOTE").eyebrowStyle()
                Text(coachTitle).font(.title3.weight(.bold))
                Text(coachCopy).foregroundStyle(Theme.muted)
            }
            .padding(16)
            .background(Color(red: 0.96, green: 0.97, blue: 0.93), in: RoundedRectangle(cornerRadius: 18))
        }
        .padding(20)
        .fairCard()
    }

    private var coachTitle: String {
        if store.swing.isZeroed { return "Take a swing to coach it." }
        if store.swing.impactQuality >= 85 { return "Keep that tempo." }
        if abs(store.swing.swingPathDeg) > 4 { return "Quiet the path first." }
        if store.swing.attackAngleDeg < -6 { return "Shallow the attack." }
        return "Solid building block."
    }

    private var coachCopy: String {
        if store.swing.isZeroed {
            return "Connect GolfMat over Bluetooth, or use the simulator to populate the lab."
        }
        let smash = store.swing.smash.map { String(format: "%.2f", $0) } ?? "—"
        return "Ball \(Int(store.swing.ballSpeedMph.rounded())) mph · club \(Int(store.swing.clubSpeedMph.rounded())) mph · smash \(smash) · attack \(String(format: "%.1f", store.swing.attackAngleDeg))° · path \(String(format: "%.1f", store.swing.swingPathDeg))°. Pressure \(store.swing.heelPressurePct)/\(store.swing.centerPressurePct)/\(store.swing.toePressurePct) heel/center/toe\(store.swing.radarValid ? " · radar locked" : "")."
    }
}

struct FlowButtons<Content: View>: View {
    @ViewBuilder var content: Content
    var body: some View {
        VStack(alignment: .trailing, spacing: 8) { content }
    }
}

struct SoftPill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(Theme.greenDark)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(red: 0.91, green: 0.96, blue: 0.93).opacity(configuration.isPressed ? 0.7 : 1), in: Capsule())
    }
}

struct GreenPill: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.green.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
    }
}

@ViewBuilder
func pill(_ title: String, emphasized: Bool = false, dark: Bool = false, demo: Bool = false, enabled: Bool = true, action: @escaping () -> Void) -> some View {
    Button(title, action: action)
        .font(.caption.weight(.bold))
        .foregroundStyle(emphasized || dark ? .white : (demo ? Color(red: 0.4, green: 0.32, blue: 0.05) : Theme.greenDark))
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            emphasized ? Theme.green : dark ? Theme.greenDark : demo ? Color(red: 1, green: 0.95, blue: 0.73) : Color(red: 0.93, green: 0.96, blue: 0.94),
            in: Capsule()
        )
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.45)
}
