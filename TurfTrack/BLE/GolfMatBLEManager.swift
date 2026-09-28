import Combine
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
    /// The link dropped (or Bluetooth turned off) and a pending reconnect is waiting for the mat.
    @Published private(set) var isReconnecting = false
    @Published var armed = false
    @Published var lastPacket: SwingPacket?

    private var central: CBCentralManager!
    private var peripheral: CBPeripheral?
    private var swingCharacteristic: CBCharacteristic?
    private let memory = BLEDeviceMemory(prefix: "fairlie.ble.mat")

    var isConnected: Bool { connectionState == .connected }

    var statusTitle: String {
        if isReconnecting && !isConnected { return "Reconnecting…" }
        switch connectionState {
        case .disconnected: return "Offline"
        case .scanning: return "Scanning…"
        case .connecting: return "Connecting…"
        case .connected: return armed ? "Armed" : "Connected"
        case .unsupported: return "Bluetooth unavailable"
        }
    }

    var statusDetail: String {
        if isReconnecting && !isConnected {
            return "GolfMat will reconnect automatically when it's powered on and in range. Tap Disconnect to stop."
        }
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
        startScan()
    }

    private func startScan() {
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
        memory.autoReconnect = false
        isReconnecting = false
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

    /// Resumes the last mat after launch or when Bluetooth comes back on, unless the user disconnected.
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
        deviceName = target.name ?? deviceName ?? Self.deviceName
        target.delegate = self
        connectionState = .connecting
        central.connect(target, options: nil)
    }

    /// Zeros the UI and arms strike gating. Hardware tare still needs USB `CAL` on the ESP.
    func calibrateAndArm() {
        lastPacket = nil
        errorMessage = nil
    }

    private func stopScan() {
        if central.isScanning {
            central.stopScan()
        }
    }

    private func handleSwingData(_ data: Data) {
        do {
            let packet = try SwingPacket(data: data)
            guard Int(packet.impactQuality) >= Self.minimumImpactQuality else { return }
            lastPacket = packet
        } catch {
            errorMessage = "Bad swing packet: \(error.localizedDescription)"
        }
    }
}

/// Remembers the last peripheral per device and whether the user wants it reconnected.
struct BLEDeviceMemory {
    let prefix: String
    private let defaults = UserDefaults.standard

    init(prefix: String) { self.prefix = prefix }

    var autoReconnect: Bool {
        get { defaults.bool(forKey: "\(prefix).autoReconnect") }
        nonmutating set { defaults.set(newValue, forKey: "\(prefix).autoReconnect") }
    }

    func remember(_ peripheral: CBPeripheral) {
        defaults.set(peripheral.identifier.uuidString, forKey: "\(prefix).lastPeripheral")
        autoReconnect = true
    }

    func retrieve(from central: CBCentralManager) -> CBPeripheral? {
        guard let raw = defaults.string(forKey: "\(prefix).lastPeripheral"),
              let id = UUID(uuidString: raw)
        else { return nil }
        return central.retrievePeripherals(withIdentifiers: [id]).first
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
                self.resumeIfNeeded()
            case .unauthorized:
                self.connectionState = .disconnected
                self.errorMessage = "Allow Bluetooth for fairLie in Settings."
            case .unsupported:
                self.connectionState = .unsupported
            default:
                self.connectionState = .disconnected
                self.armed = false
                self.swingCharacteristic = nil
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
            let name = peripheral.name
                ?? advertisementData[CBAdvertisementDataLocalNameKey] as? String
            let services = advertisementData[CBAdvertisementDataServiceUUIDsKey] as? [CBUUID] ?? []
            let matchesService = services.contains(Self.serviceUUID)
            let matchesName = name?.localizedCaseInsensitiveContains("Golf") == true
                || name == Self.deviceName
            let isRadar = name?.localizedCaseInsensitiveContains("Radar") == true
                || services.contains(RadarBLEManager.serviceUUID)
            guard (matchesService || matchesName), !isRadar else { return }

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
            self.memory.remember(peripheral)
            self.isReconnecting = false
            peripheral.discoverServices([Self.serviceUUID])
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didFailToConnect peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            guard self.memory.autoReconnect else {
                self.connectionState = .disconnected
                self.errorMessage = error?.localizedDescription ?? "Connection failed."
                self.peripheral = nil
                return
            }
            self.isReconnecting = true
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard self.memory.autoReconnect, !self.isConnected, central.state == .poweredOn else { return }
            self.reconnect(peripheral)
        }
    }

    nonisolated func centralManager(
        _ central: CBCentralManager,
        didDisconnectPeripheral peripheral: CBPeripheral,
        error: Error?
    ) {
        Task { @MainActor in
            self.armed = false
            self.swingCharacteristic = nil
            if self.memory.autoReconnect, central.state == .poweredOn {
                self.isReconnecting = true
                self.errorMessage = nil
                self.reconnect(peripheral)
                return
            }
            self.connectionState = .disconnected
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
