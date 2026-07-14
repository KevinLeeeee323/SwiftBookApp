import Foundation
import Compression

// MARK: - Minimal ZIP Reader for EPUB files
// Handles stored (uncompressed) and deflated entries — covers virtually all EPUBs.

enum ZipError: LocalizedError {
    case invalidFormat
    case unsupportedCompression(String)
    case entryNotFound(String)
    case decompressionFailed

    var errorDescription: String? {
        switch self {
        case .invalidFormat:           return "无效的 ZIP 文件格式"
        case .unsupportedCompression(let m): return "不支持的压缩方式: \(m)"
        case .entryNotFound(let name): return "找不到文件: \(name)"
        case .decompressionFailed:     return "解压失败"
        }
    }
}

struct ZipEntry: Sendable {
    let filename: String
    let compressedSize: UInt64
    let uncompressedSize: UInt64
    let compressionMethod: UInt16
    let dataOffset: UInt64
    let crc32: UInt32

    var isDirectory: Bool { filename.hasSuffix("/") }
}

final class ZipReader: @unchecked Sendable {
    private let data: Data

    // MARK: - Init
    init(data: Data) {
        self.data = data
    }

    convenience init(contentsOf url: URL) throws {
        let data = try Data(contentsOf: url)
        self.init(data: data)
    }

    // MARK: - Central Directory
    func centralDirectory() throws -> [ZipEntry] {
        guard let eocdOffset = findEOCDOffset() else {
            throw ZipError.invalidFormat
        }

        var reader = DataReader(data: data, offset: eocdOffset)

        // EOCD: signature(4) + diskNumber(2) + cdDisk(2) + cdEntriesOnDisk(2) + cdTotalEntries(2) + cdSize(4) + cdOffset(4) + commentLen(2)
        _ = reader.readUInt32()         // signature
        _ = reader.readUInt16()         // diskNumber
        _ = reader.readUInt16()         // cdDisk
        let cdCount = reader.readUInt16()     // entries on this disk
        _ = reader.readUInt16()               // total entries (may differ for multi-disk)
        _ = reader.readUInt32()               // cdSize
        let cdOffset = UInt64(reader.readUInt32())
        // commentLen ignored

        guard cdCount > 0, cdOffset < data.count else {
            throw ZipError.invalidFormat
        }

        var entries: [ZipEntry] = []
        var cdReader = DataReader(data: data, offset: Int(cdOffset))

        for _ in 0..<cdCount {
            let sig = cdReader.readUInt32()
            // 0x02014b50 = central directory file header signature
            guard sig == 0x02014b50 else { throw ZipError.invalidFormat }

            _ = cdReader.readUInt16()    // versionMadeBy
            _ = cdReader.readUInt16()    // versionNeeded
            _ = cdReader.readUInt16()    // flags
            let method = cdReader.readUInt16()
            _ = cdReader.readUInt16()    // modTime
            _ = cdReader.readUInt16()    // modDate
            let crc32 = cdReader.readUInt32()
            let compressedSize = UInt64(cdReader.readUInt32())
            let uncompressedSize = UInt64(cdReader.readUInt32())
            let fnLen = cdReader.readUInt16()
            let extraLen = cdReader.readUInt16()
            let commentLen = cdReader.readUInt16()
            _ = cdReader.readUInt16()    // diskNumberStart
            _ = cdReader.readUInt16()    // internalAttrs
            _ = cdReader.readUInt32()    // externalAttrs
            let localHeaderOffset = UInt64(cdReader.readUInt32())

            guard let filename = cdReader.readString(length: Int(fnLen)) else {
                throw ZipError.invalidFormat
            }
            cdReader.skip(Int(extraLen))
            cdReader.skip(Int(commentLen))

            entries.append(ZipEntry(
                filename: filename,
                compressedSize: compressedSize,
                uncompressedSize: uncompressedSize,
                compressionMethod: method,
                dataOffset: localHeaderOffset,
                crc32: crc32
            ))
        }

        return entries
    }

    // MARK: - Read entry data
    func read(entry: ZipEntry) throws -> Data {
        var reader = DataReader(data: data, offset: Int(entry.dataOffset))

        let sig = reader.readUInt32()
        // 0x04034b50 = local file header signature
        guard sig == 0x04034b50 else { throw ZipError.invalidFormat }

        _ = reader.readUInt16()          // version
        _ = reader.readUInt16()          // flags
        let method = reader.readUInt16()
        _ = reader.readUInt16()          // modTime
        _ = reader.readUInt16()          // modDate
        _ = reader.readUInt32()          // crc32
        let compSize = Int(reader.readUInt32())
        let uncompSize = Int(reader.readUInt32())
        let fnLen = reader.readUInt16()
        let extraLen = reader.readUInt16()
        reader.skip(Int(fnLen))
        reader.skip(Int(extraLen))

        let raw = reader.readData(length: compSize)

        switch method {
        case 0: // stored
            return raw
        case 8: // deflated
            return try inflate(data: raw, expectedSize: uncompSize)
        default:
            throw ZipError.unsupportedCompression("method=\(method)")
        }
    }

    // MARK: - Convenience
    func read(filename: String) throws -> Data {
        let entries = try centralDirectory()

        // 1. Exact match
        if let entry = entries.first(where: { $0.filename == filename && !$0.isDirectory }) {
            return try read(entry: entry)
        }

        // 2. Match by suffix (handle path format differences)
        let normalized = filename.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if let entry = entries.first(where: { entry in
            !entry.isDirectory && (
                entry.filename.hasSuffix(normalized) ||
                entry.filename.replacingOccurrences(of: "./", with: "").hasSuffix(normalized) ||
                entry.filename.replacingOccurrences(of: "../", with: "").hasSuffix(normalized)
            )
        }) {
            return try read(entry: entry)
        }

        throw ZipError.entryNotFound(filename)
    }

    func findFiles(matching pattern: String) throws -> [String] {
        let entries = try centralDirectory()
        return entries
            .filter { !$0.isDirectory }
            .map(\.filename)
            .filter { $0.hasSuffix(pattern) || $0.contains(pattern) }
    }

    // MARK: - Private helpers
    private func findEOCDOffset() -> Int? {
        let searchStart = max(0, data.count - 65557) // max comment size + EOCD
        _ = data.count - searchStart

        // EOCD signature: 0x06054b50 (little-endian: 50 4b 05 06)
        let signature: [UInt8] = [0x50, 0x4b, 0x05, 0x06]

        for i in stride(from: data.count - 22, through: searchStart, by: -1) {
            var match = true
            for j in 0..<4 {
                if data[i + j] != signature[j] { match = false; break }
            }
            if match { return i }
        }
        return nil
    }

    private func inflate(data: Data, expectedSize: Int) throws -> Data {
        var result = Data(count: expectedSize)
        let status = result.withUnsafeMutableBytes { outPtr in
            data.withUnsafeBytes { inPtr in
                compression_decode_buffer(
                    outPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    expectedSize,
                    inPtr.baseAddress!.assumingMemoryBound(to: UInt8.self),
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }
        guard status == expectedSize else {
            throw ZipError.decompressionFailed
        }
        return result
    }
}

// MARK: - DataReader helper
private struct DataReader {
    let data: Data
    var offset: Int

    mutating func readUInt16() -> UInt16 {
        let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt16.self) }
        offset += 2
        return UInt16(littleEndian: value)
    }

    mutating func readUInt32() -> UInt32 {
        let value = data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: offset, as: UInt32.self) }
        offset += 4
        return UInt32(littleEndian: value)
    }

    mutating func readString(length: Int) -> String? {
        guard length > 0, offset + length <= data.count else { return nil }
        let str = String(data: data.subdata(in: offset..<offset + length), encoding: .utf8)
        offset += length
        return str
    }

    mutating func readData(length: Int) -> Data {
        let actual = min(length, data.count - offset)
        let d = data.subdata(in: offset..<offset + actual)
        offset += actual
        return d
    }

    mutating func skip(_ count: Int) {
        offset += count
    }
}
