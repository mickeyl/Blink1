import Foundation

extension Blink1 {

    /// Everything known about an attached blink(1) without talking to it.
    public struct Info: Sendable, Hashable, Codable, CustomStringConvertible {

        public let serialNumber: String
        public let productName: String
        public let model: Model
        public let locationID: UInt32?

        init(serialNumber: String, productName: String, locationID: UInt32?) {
            self.serialNumber = serialNumber
            self.productName = productName
            self.model = Model(serialNumber: serialNumber)
            self.locationID = locationID
        }

        public var description: String { "\(productName) (\(serialNumber))" }
    }
}
