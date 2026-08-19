import Foundation

/// Packed BLE notify payload — mirrors `ble_swing_packet_t` (little-endian).
struct SwingPacket {
    let timestampMs: UInt32
    let fsrPeaks: [UInt16] // 6
    let impactDurationUs: UInt16
    let impactZone: UInt8
    let impactQuality: UInt8
    let contactZoneLabel: UInt8
    let estimatedDistanceM: UInt16
    let consistencyHint: UInt8
    let flags: UInt8
    let accelXMg: Int16
    let accelYMg: Int16
    let accelZMg: Int16
    let gyroXMdps: Int16
    let gyroYMdps: Int16
    let gyroZMdps: Int16
    let yawDeg10: Int16
    let strikeZone: UInt8
    let strikeDirection: UInt8
    let heelPressurePct: UInt8
    let centerPressurePct: UInt8
    let toePressurePct: UInt8
    let directionPenalty: UInt8
    let radarSpeedMph10: Int16
    let radarDistanceMm: Int16
    let radarIntraScore: UInt16
    let radarValid: UInt8

    static let minimumByteCount = 52

    init(data: Data) throws {
        guard data.count >= Self.minimumByteCount else {
            throw DecodeError.tooShort(data.count)
        }

        func u16(_ offset: Int) -> UInt16 {
            UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
        }
        func i16(_ offset: Int) -> Int16 {
            Int16(bitPattern: u16(offset))
        }
        func u32(_ offset: Int) -> UInt32 {
            UInt32(u16(offset)) | (UInt32(u16(offset + 2)) << 16)
        }

        timestampMs = u32(0)
        fsrPeaks = (0..<6).map { u16(4 + $0 * 2) }
        impactDurationUs = u16(16)
        impactZone = data[18]
        impactQuality = data[19]
        contactZoneLabel = data[20]
        estimatedDistanceM = u16(21)
        consistencyHint = data[23]
        flags = data[24]
        accelXMg = i16(25)
        accelYMg = i16(27)
        accelZMg = i16(29)
        gyroXMdps = i16(31)
        gyroYMdps = i16(33)
        gyroZMdps = i16(35)
        yawDeg10 = i16(37)
        strikeZone = data[39]
        strikeDirection = data[40]
        heelPressurePct = data[41]
        centerPressurePct = data[42]
        toePressurePct = data[43]
        directionPenalty = data[44]
        radarSpeedMph10 = i16(45)
        radarDistanceMm = i16(47)
        radarIntraScore = u16(49)
        radarValid = data[51]
    }

    enum DecodeError: Error {
        case tooShort(Int)
    }
}

enum StrikeDirection: UInt8 {
    case straight = 0
    case left = 1
    case right = 2
    case push = 3
    case pull = 4

    var label: String {
        switch self {
        case .straight: return "Straight"
        case .left: return "Left"
        case .right: return "Right"
        case .push: return "Push"
        case .pull: return "Pull"
        }
    }
}
