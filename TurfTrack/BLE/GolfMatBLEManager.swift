import CoreBluetooth
import Foundation

@MainActor
final class GolfMatBLEManager: NSObject, ObservableObject {
    static let serviceUUID = CBUUID(string: "AB12")
    static let swingUUID = CBUUID(string: "AB13")
    static let deviceName = "GolfMat"
    /// Match web client: ignore weak / noise notifies.
    static let minimumImpactQuality = 35

    @Published private(set) var connectionState: ConnectionState = .disconnected
    @Published private(set) var deviceName: String?
    @Published private(set) var errorMessage: String?
    @Published private(set) var armed = false
    @Published private(set) var lastSwing: SwingResult?
    @Published private(set) var history: [SwingResult] = []

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var swingCharacteristic: CBCharacteristic?

    var isConnected: Bool { connectionState == .connected }

    var waitingForStrike: Bool {
        armed && (lastSwing == nil || lastSwing?.isZeroed == true)
    }

    var displaySwing: SwingResult {
        lastSwing ?? .zeroed
    }

    var statusTitle: String {
        switch connectionState {
        case .disconnected: return "Offline"
        case .scanning: return "Scanning…"
        case .connecting: return "Connecting…"
        case .connected: return armed ? "Armed" : "Connected"
        case .unsupported: return "Bluetooth unavailable"
        }
    }

    var statusDetail: String {
        if let errorMessage { return errorMessage }
        switch connectionState {
        case .disconnected:
            return "Tap Connect to find GolfMat."
        case .scanning:
            return "Looking for GolfMat / service 0xAB12…"
        case .connecting:
            return "Linking to \(deviceName ?? "mat")…"
        case .connected:
            return armed
                ? "Pads at 0 — waiting for a full strike."
                : "Press Calibrate / Zero, then swing."
        case .unsupported:
            return "Enable Bluetooth and try again."
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
            errorMessage = "Turn on Bluetooth, then Connect."
            return
        }
        connectionState = .scanning
        central.scanForPeripherals(
            withServices: [Self.serviceUUID],
            options: [CBCentralManagerScanOptionAllowDuplicatesKey: false]
        )
        // Also catch named ads that omit the service in the ADV payload.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self, self.connectionState == .scanning else { return }
            self.central.scanForPeripherals(withServices: nil, options: nil)
        }
    }

    func disconnect() {
        if let peripheral {
            central.cancelPeripheralConnection(peripheral)
        }
        stopScan()
        peripheral = nil
        swingCharacteristic = nil
        armed = false
        connectionState = .disconnected
        deviceName = nil
    }

    /// Zeros the UI and arms strike gating. Hardware tare still needs USB `CAL` on the ESP.
    func calibrateAndArm() {
        guard isConnected else {
            errorMessage = "Connect to GolfMat first."
            return
        }
        armed = true
        lastSwing = SwingResult(
            id: UUID(),
            timestampMs: 0,
            receivedAt: Date(),
            fsrPeaks: [0, 0, 0, 0, 0, 0],
            impactZone: -1,
            impactQuality: 0,
            estimatedDistanceM: 0,
            directionLabel: "Armed",
            heelPressurePct: 0,
            centerPressurePct: 0,
            toePressurePct: 0,
            isZeroed: true
        )
        errorMessage = nil
    }

    private func stopScan() {
        if central.isScanning {
            central.stopScan()
        }
    }

    private func handleSwingData(_ data: Data) {
        guard armed else { return }
        do {
            let packet = try SwingPacket(data: data)
            guard Int(packet.impactQuality) >= Self.minimumImpactQuality else { return }
            let swing = SwingResult.from(packet: packet)
            lastSwing = swing
            history = Array((history + [swing]).suffix(50))
        } catch {
            errorMessage = "Bad swing packet: \(error.localizedDescription)"
        }
    }
}

extension GolfMatBLEManager {
    enum ConnectionState: Equatable {
        case disconnected
        case scanning
        case connecting
        case connected
        case unsupported
    }
}

extension GolfMatBLEManager: CBCentralManagerDelegate {
    nonisolated func centralManagerDidUpdateState(_ central: CBCentralManager) {
        Task { @MainActor in
            switch central.state {
            case .poweredOn:
                break
            case .unauthorized:
                self.connectionState = .disconnected
                self.errorMessage = "Allow Bluetooth for TurfTrack in Settings."
            case .unsupported:
                self.connectionState = .unsupported
            default:
                if self.connectionState != .disconnected {
                    self.connectionState = .disconnected
                }
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
            let name = peripheral.name
                ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            let matchesService = services.contains(Self.serviceUUID)
            let matchesName = name?.localizedCaseInsensitiveContains("Golf") == true
                || name == Self.deviceName
            guard matchesService || matchesName else { return }

            self.stopScan()
            self.peripheral = peripheral
            self.deviceName = name ?? Self.deviceName
            self.connectionState = .connecting
            peripheral.delegate = self
            central.connect(peripheral, options: nil)
        }
    }

    nonisolated func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        Task { @MainActor in
            self.connectionState = .connected
            self.errorMessage = nil
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.connectionState = .disconnected
            self.errorMessage = error?.localizedDescription ?? "Connection failed."
            self.peripheral = nil
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.connectionState = .disconnected
            self.armed = false
            self.swingCharacteristic = nil
            self.peripheral = nil
            if let error {
                self.errorMessage = error.localizedDescription
            }
        }
    }
}

extension GolfMatBLEManager: CBPeripheralDelegate {
    nonisolated func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let service = peripheral.services?.first(where: { $0.uuid == Self.serviceUUID }) else {
                self.errorMessage = "GolfMat service 0xAB12 missing. Reflash firmware."
                return
            }
            peripheral.discoverCharacteristics([Self.swingUUID], for: service)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didDiscoverCharacteristicsFor service: CBService,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard let characteristic = service.characteristics?.first(where: { $0.uuid == Self.swingUUID }) else {
                self.errorMessage = "Swing notify 0xAB13 missing."
                return
            }
            self.swingCharacteristic = characteristic
            peripheral.setNotifyValue(true, for: characteristic)
        }
    }

    nonisolated func peripheral(
        _ peripheral: CBPeripheral,
        didUpdateValueFor characteristic: CBCharacteristic,
        error: Error?
    ) {
        Task { @MainActor in
            if let error {
                self.errorMessage = error.localizedDescription
                return
            }
            guard characteristic.uuid == Self.swingUUID, let data = characteristic.value else { return }
            self.handleSwingData(data)
        }
    }
}
