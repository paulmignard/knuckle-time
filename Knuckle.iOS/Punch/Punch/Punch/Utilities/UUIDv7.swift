import Foundation

extension UUID {
    /// Generate a UUIDv7 (time-ordered UUID)
    static func v7() -> UUID {
        var bytes = [UInt8](repeating: 0, count: 16)

        // First 48 bits: Unix timestamp in milliseconds
        let timestamp = UInt64(Date().timeIntervalSince1970 * 1000)
        bytes[0] = UInt8((timestamp >> 40) & 0xFF)
        bytes[1] = UInt8((timestamp >> 32) & 0xFF)
        bytes[2] = UInt8((timestamp >> 24) & 0xFF)
        bytes[3] = UInt8((timestamp >> 16) & 0xFF)
        bytes[4] = UInt8((timestamp >> 8) & 0xFF)
        bytes[5] = UInt8(timestamp & 0xFF)

        // Next 4 bits: version (7)
        // Next 12 bits: random
        var random = UInt16.random(in: 0...UInt16.max)
        random = (random & 0x0FFF) | 0x7000
        bytes[6] = UInt8((random >> 8) & 0xFF)
        bytes[7] = UInt8(random & 0xFF)

        // Next 2 bits: variant (10)
        // Next 62 bits: random
        for i in 8..<16 {
            bytes[i] = UInt8.random(in: 0...255)
        }
        bytes[8] = (bytes[8] & 0x3F) | 0x80

        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
