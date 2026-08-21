import Foundation

extension Blink1 {

    /// The hardware generation, derived from the serial number range.
    public enum Model: String, Sendable, Hashable, Codable, CaseIterable, CustomStringConvertible {

        case mk1
        case mk2
        case mk3
        case mk4
        case unknown

        /// Serial numbers are 8 hex digits whose most significant nibble encodes the generation.
        init(serialNumber: String) {
            guard let serial = UInt32(serialNumber, radix: 16) else { self = .unknown; return }
            self = switch serial {
                case 0x4000_0000...: .mk4
                case 0x3000_0000...: .mk3
                case 0x2000_0000...: .mk2
                default: .mk1
            }
        }

        public var description: String { self.rawValue }

        /// Number of individually addressable LEDs.
        public var ledCount: Int { self == .mk1 ? 1 : 2 }

        /// Size of the on-device color pattern.
        public var patternSlots: Int {
            switch self {
                case .mk1, .mk2: 16
                case .mk3, .mk4: 32
                case .unknown: 0
            }
        }

        /// mk2 and later gamma-correct in firmware, mk1 expects the host to do it.
        public var correctsGammaInFirmware: Bool { self != .mk1 && self != .unknown }

        /// Playing a sub-range with a repeat count (rather than just "play from position").
        public var supportsPatternLoop: Bool { self != .mk1 }

        /// Addressing a single LED instead of both.
        public var supportsIndividualLEDs: Bool { self != .mk1 }

        /// The 50-byte user "notes" storage, the chip ID and the bootloader commands (report 2).
        public var supportsNotes: Bool { self == .mk3 || self == .mk4 }
    }
}
