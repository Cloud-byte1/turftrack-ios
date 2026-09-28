import Combine
import CoreBluetooth
import Foundation

/// One reading from the dedicated XM125 radar ESP32.
/// Wire format (UTF-8 notify): `GMRADAR,<ms>,<mph>,<dist_mm>,<intra>,<inter>,<valid>`
struct RadarSample: Equatable {
    var receivedAt: Date
    var timestampMs: UInt32
    var speedMph: Double
    var distanceMm: Int
    var intraScore: Int
    var interScore: Int
    var valid: Bool

    init?(line: String) {
        let parts = line.trimmingCharacters(in: .whitespacesAndNewlines).split(separator: ",")
        guard parts.count == 7, parts[0].uppercased() == "GMRADAR" else { return nil }
        let mph = Double(parts[2]) ?? 0
        receivedAt = Date()
        timestampMs = UInt32(parts[1]) ?? 0
        speedMph = mph
        distanceMm = Int(Double(parts[3]) ?? 0)
        intraScore = Int(Double(parts[4]) ?? 0)
        interScore = Int(Double(parts[5]) ?? 0)
        valid = parts[6] == "1" && mph > 0
    }
}

@MainActor
final class RadarBLEManager: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "AB20")
    static let radarUUID = CBUUID(string: "AB21")
    static let deviceName = "GolfMatRadar"
    /// A radar reading older than this is not attributed to a mat strike.
    static let mergeWindow: TimeInterval = 0.75

    @Published private(set) var connectionState: GolfMatBLEManager.ConnectionState = .disconnected
    @Published private(set) var errorMessage: String?
    @Published private(set) var latest: RadarSample?
    @Published private(set) var lastValid: RadarSample?
    /// The link dropped (or Bluetooth turned off) and a pending reconnect is waiting for the radar.
    @Published private(set) var isReconnecting = false

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private let memory = BLEDeviceMemory(prefix: "fairlie.ble.radar")

    var isConnected: Bool { connectionState == .connected }

    var statusTitle: String {
        if isReconnecting && !isConnected { return "Reconnecting radar…" }
        switch connectionState {
        case .disconnected: return "Radar offline"
        case .scanning: return "Scanning for radar…"
        case .connecting: return "Connecting radar…"
        case .connected: return lastValid == nil ? "Radar linked" : "Radar motion locked"
        case .unsupported: return "Bluetooth unavailable"
        }
    }

    var statusDetail: String {
        if isReconnecting && !isConnected {
            return "The radar will reconnect automatically when it's powered on and in range. Tap Disconnect to stop."
        }
        if let errorMessage { return errorMessage }
        switch connectionState {
        case .disconnected: return "Tap Radar BLE to link the XM125 ESP32."
        case .scanning: return "Looking for GolfMatRadar / service 0xAB20…"
        case .connecting: return "Linking to GolfMatRadar…"
        case .connected:
            if let latest {
                return String(format: "%.1f mph · %d mm · intra %d", latest.speedMph, latest.distanceMm, latest.intraScore)
            }
            return "Waiting for radar readings…"
        case .unsupported: return "Enable Bluetooth and try again."
        }
    }

    override init() {
        super.init()
        central = CBCentralManager(delegate: self, queue: nil)
    }

    func connect() {
        errorMessage = nil
        guard central.state == .poweredOn else {
            connectionState = central.state == .unsupported ? .unsupported : .disconnected
            errorMessage = "Turn on Bluetooth, then connect the radar."
            return
        }
        startScan()
    }

    private func startScan() {
        connectionState = .scanning
        central.scanForPeripherals(withServices: [Self.serviceUUID], options: nil)
    }

    /// Resumes the last radar after launch or when Bluetooth comes back on, unless the user disconnected.
    private func resumeIfNeeded() {
        guard memory.autoReconnect, central.state == .poweredOn,
              connectionState != .connected, connectionState != .connecting, connectionState != .scanning
        else { return }
        isReconnecting = true
        errorMessage = nil
        if let known = peripheral ?? memory.retrieve(from: central) {
            reconnect(known)
        } else {
            startScan()
        }
    }

    private func reconnect(_ target: CBPeripheral) {
        peripheral = target
        target.delegate = self
        connectionState = .connecting
        central.connect(target, options: nil)
    }

    func disconnect() {
        memory.autoReconnect = false
        isReconnecting = false
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        if central.isScanning { central.stopScan() }
        peripheral = nil
        latest = nil
        lastValid = nil
        connectionState = .disconnected
    }

    /// The most recent valid reading, if it is fresh enough to belong to a strike happening now.
    func sampleForStrike(at date: Date = Date()) -> RadarSample? {
        guard let lastValid, abs(date.timeIntervalSince(lastValid.receivedAt)) <= Self.mergeWindow else { return nil }
        return lastValid
    }

    private func handle(_ data: Data) {
        guard let text = String(data: data, encoding: .utf8) else { return }
        for line in text.split(whereSeparator: \.isNewline) {
            guard let sample = RadarSample(line: String(line)) else { continue }
            latest = sample
            if sample.valid { lastValid = sample }
        }
    }
}

extension RadarBLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                self.resumeIfNeeded()
            case .unauthorized:
                self.connectionState = .disconnected
                self.errorMessage = "Allow Bluetooth for fairLie in Settings."
            case .unsupported:
                self.connectionState = .unsupported
            default:
                self.connectionState = .disconnected
                self.latest = nil
                self.lastValid = nil
                if self.memory.autoReconnect { self.isReconnecting = true }
            }
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDiscover peripheral: CBPeripheral,
        advertisementData: [String: Any],
        rssi RSSI: NSNumber
    ) {
        Task { @MainActor in
            guard self.connectionState == .scanning else { return }
            central.stopScan()
            self.peripheral = peripheral
            self.connectionState = .connecting
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connectionState = .connected
            self.errorMessage = nil
            self.memory.remember(peripheral)
            self.isReconnecting = false
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            guard self.memory.autoReconnect else {
                self.connectionState = .disconnected
                self.errorMessage = error?.localizedDescription ?? "Radar connection failed."
                self.peripheral = nil
                return
            }
            self.isReconnecting = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard self.memory.autoReconnect, !self.isConnected, central.state == .poweredOn else { return }
            self.reconnect(peripheral)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didDisconnectPeripheral peripheral: CBPeripheral, error: Error?) {
        Task { @MainActor in
            self.latest = nil
            self.lastValid = nil
            if self.memory.autoReconnect, central.state == .poweredOn {
                self.isReconnecting = true
                self.errorMessage = nil
                self.reconnect(peripheral)
                return
            }
            self.connectionState = .disconnected
            self.peripheral = nil
            if let error { self.errorMessage = error.localizedDescription }
        }
    }
}

extension RadarBLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
                self.errorMessage = "Radar service 0xAB20 missing. Reflash radar_stream.ino."
                return
            }
            peripheral.discoverCharacteristics([Self.radarUUID], for: service)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.radarUUID }) else {
                self.errorMessage = "Radar notify 0xAB21 missing."
                return
            }
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(_ peripheral: CBPeripheral, didUpdateValueFor characteristic: CBCharacteristic, error: Error?) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard characteristic.uuid == Self.radarUUID, let data = characteristic.value else { return }
            self.handle(data)
        }
    }
}

extension SwingResult {
    /// Mat strike with ball speed taken from the separate radar ESP.
    func mergingRadar(_ sample: RadarSample) -> SwingResult {
        var merged = self
        merged.ballSpeedMph = sample.speedMph
        merged.clubSpeedMph = min(130, max(40, sample.speedMph / 1.35))
        merged.radarValid = true
        merged.radarDistanceMm = sample.distanceMm
        merged.radarIntraScore = sample.intraScore
        return merged
    }
}
