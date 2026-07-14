import Foundation
import SwiftUI

// MARK: - EPUB Parser
final class EPUBParser: @unchecked Sendable {

    // MARK: - Parse EPUB
    func parse(epubURL: URL) throws -> ParsedEPUB {
        let data = try Data(contentsOf: epubURL)
        let zip = ZipReader(data: data)
        let entries = try zip.centralDirectory()

        // 1. Find and parse container.xml
        guard let containerEntry = entries.first(where: { $0.filename == "META-INF/container.xml" }) else {
            throw EPUBError.missingContainerXML
        }
        let containerData = try zip.read(entry: containerEntry)
        let opfPath = try extractOPFPath(from: containerData)

        // 2. Parse the OPF file
        guard let opfEntry = entries.first(where: { $0.filename == opfPath || $0.filename.hasSuffix("/\(opfPath)") }) else {
            // Try fuzzy match
            let match = entries.first(where: { $0.filename.hasSuffix(opfPath) || opfPath.hasSuffix($0.filename) })
            guard let opfEntry = match else {
                throw EPUBError.missingOPF("OPF 路径: \(opfPath)")
            }
            let opfData = try zip.read(entry: opfEntry)
            let opfDir = (opfEntry.filename as NSString).deletingLastPathComponent
            return try parseOPF(data: opfData, baseDir: opfDir, zip: zip, entries: entries, epubURL: epubURL)
        }

        let opfData = try zip.read(entry: opfEntry)
        let opfDir = (opfEntry.filename as NSString).deletingLastPathComponent
        return try parseOPF(data: opfData, baseDir: opfDir, zip: zip, entries: entries, epubURL: epubURL)
    }

    // MARK: - Extract OPF path from container.xml
    private func extractOPFPath(from data: Data) throws -> String {
        let xml = String(decoding: data, as: UTF8.self)

        // Look for rootfile full-path attribute
        // <rootfile full-path="..." media-type="application/oebps-package+xml"/>
        let patterns = [
            #"full-path\s*=\s*"([^"]+)""#,
            #"full-path\s*=\s*'([^']+)'"#,
        ]

        for pattern in patterns {
            if let range = xml.range(of: pattern, options: .regularExpression) {
                let match = xml[range]
                if let valueRange = match.range(of: #""[^"]+""#, options: .regularExpression)
                    ?? match.range(of: #"'[^']+'"#, options: .regularExpression) {
                    var value = String(match[valueRange])
                    value.removeFirst()
                    value.removeLast()
                    return value
                }
            }
        }

        throw EPUBError.missingOPF("container.xml 中找不到 OPF 路径")
    }

    // MARK: - Parse OPF
    private func parseOPF(data: Data, baseDir: String, zip: ZipReader, entries: [ZipEntry], epubURL: URL) throws -> ParsedEPUB {
        let xml = String(decoding: data, as: UTF8.self)

        // Parse metadata
        let title = extractXMLElement(xml, tag: "dc:title") ?? extractXMLElement(xml, tag: "title") ?? "未知书名"
        let author = extractXMLElement(xml, tag: "dc:creator") ?? extractXMLElement(xml, tag: "creator") ?? "未知作者"

        // Parse manifest (id → href)
        var manifest: [String: String] = [:]
        let manifestPattern = #"<item[^>]+>"#
        if let regex = try? NSRegularExpression(pattern: manifestPattern, options: []) {
            let nsXML = xml as NSString
            let matches = regex.matches(in: xml, range: NSRange(location: 0, length: nsXML.length))
            for match in matches {
                let item = nsXML.substring(with: match.range)
                let itemId = extractAttribute(item, attr: "id") ?? ""
                let itemHref = extractAttribute(item, attr: "href") ?? ""
                if !itemId.isEmpty && !itemHref.isEmpty {
                    manifest[itemId] = itemHref
                }
            }
        }

        // Parse spine (ordered list of content IDs)
        var spineIDs: [String] = []
        let spinePatterns = [#"<itemref[^>]+>"#]
        if let regex = try? NSRegularExpression(pattern: spinePatterns[0], options: []) {
            let nsXML = xml as NSString
            let matches = regex.matches(in: xml, range: NSRange(location: 0, length: nsXML.length))
            for match in matches {
                let itemref = nsXML.substring(with: match.range)
                if let idref = extractAttribute(itemref, attr: "idref") {
                    spineIDs.append(idref)
                }
            }
        }

        // Build ordered href list from spine
        var spine: [String] = []
        for idref in spineIDs {
            if let href = manifest[idref] {
                spine.append(resolvePath(href, relativeTo: baseDir))
            }
        }

        // Parse chapters (from NCX if available, otherwise from spine)
        var chapters: [Chapter] = []

        // Try to find NCX (toc.ncx) from spine or manifest
        let ncxHref: String? = {
            if let ncxId = manifest.first(where: { $0.value.hasSuffix(".ncx") })?.key {
                return manifest[ncxId]
            }
            return nil
        }()

        if let ncxPath = ncxHref {
            let fullNCXPath = resolvePath(ncxPath, relativeTo: baseDir)
            if let ncxData = try? zip.read(filename: fullNCXPath) {
                chapters = try parseNCX(data: ncxData, baseDir: baseDir, spine: spine)
            }
        }

        // Fallback: create chapters from spine if NCX parsing yielded nothing
        if chapters.isEmpty {
            for (index, href) in spine.enumerated() {
                let fileName = (href as NSString).lastPathComponent
                let name = (fileName as NSString).deletingPathExtension
                chapters.append(Chapter(
                    title: name.replacingOccurrences(of: "_", with: " ").capitalized,
                    href: href,
                    playOrder: index
                ))
            }
        }

        // Extract cover image
        let coverImageData = try? extractCoverImage(zip: zip, manifest: manifest, baseDir: baseDir)

        return ParsedEPUB(
            title: title,
            author: author,
            coverImageData: coverImageData,
            chapters: chapters,
            spine: spine,
            manifest: manifest,
            baseDir: baseDir,
            zip: zip
        )
    }

    // MARK: - Parse NCX (Table of Contents)
    private func parseNCX(data: Data, baseDir: String, spine: [String]) throws -> [Chapter] {
        let ncx = String(decoding: data, as: UTF8.self)
        var chapters: [Chapter] = []

        // Extract navPoints
        let navPointPattern = #"<navPoint[^>]*>.*?</navPoint>"#
        if let regex = try? NSRegularExpression(pattern: navPointPattern, options: .dotMatchesLineSeparators) {
            let nsNCX = ncx as NSString
            let matches = regex.matches(in: ncx, range: NSRange(location: 0, length: nsNCX.length))
            for (index, match) in matches.enumerated() {
                let navPoint = nsNCX.substring(with: match.range)
                let label = extractXMLElement(navPoint, tag: "navLabel")?
                    .replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                _ = extractAttribute(navPoint, attr: "src") ?? ""
                let contentHref = extractAttribute(navPoint, attr: "src") ?? ""
                let resolvedHref = resolvePath(contentHref, relativeTo: baseDir)

                chapters.append(Chapter(
                    title: label ?? "章节 \(index + 1)",
                    href: resolvedHref,
                    playOrder: index
                ))
            }
        }

        return chapters
    }

    // MARK: - Extract cover image
    private func extractCoverImage(zip: ZipReader, manifest: [String: String], baseDir: String) throws -> Data? {
        // Look for cover in manifest
        let coverKeys = ["cover-image", "cover", "cover_jpg", "coverimage"]
        for key in coverKeys {
            if let href = manifest[key], let data = try? zip.read(filename: resolvePath(href, relativeTo: baseDir)) {
                return data
            }
        }

        // Search by filename pattern in zip entries
        let entries = try zip.centralDirectory()
        let coverPatterns = ["cover.jpg", "cover.jpeg", "cover.png", "cover_image.jpg"]
        for pattern in coverPatterns {
            if let entry = entries.first(where: { $0.filename.lowercased().hasSuffix(pattern) }),
               let data = try? zip.read(entry: entry) {
                return data
            }
        }

        return nil
    }

    // MARK: - XML Helpers (manual, iOS-compatible)
    private func extractXMLElement(_ xml: String, tag: String) -> String? {
        // Match <tag ...>content</tag> or self-closing
        let pattern = "<\(tag)[^>]*>(.*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .dotMatchesLineSeparators) else {
            return nil
        }
        let nsXML = xml as NSString
        guard let match = regex.firstMatch(in: xml, range: NSRange(location: 0, length: nsXML.length)) else {
            return nil
        }
        if match.numberOfRanges >= 2 {
            let content = nsXML.substring(with: match.range(at: 1))
            return content.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return nil
    }

    private func extractAttribute(_ xml: String, attr: String) -> String? {
        let patterns = [
            #"\#(attr)\s*=\s*"([^"]*)""#,
            #"\#(attr)\s*=\s*'([^']*)'"#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: xml, range: NSRange(xml.startIndex..., in: xml)) {
                let range = match.range(at: 1)
                if let swiftRange = Range(range, in: xml) {
                    return String(xml[swiftRange])
                }
            }
        }
        return nil
    }

    private func resolvePath(_ href: String, relativeTo baseDir: String) -> String {
        if baseDir.isEmpty || baseDir == "." { return href }

        var result = href
        // Remove fragment identifiers
        if let fragmentIndex = result.firstIndex(of: "#") {
            result = String(result[..<fragmentIndex])
        }

        // Resolve relative path
        if result.hasPrefix("./") {
            result.removeFirst(2)
        }
        while result.hasPrefix("../") {
            result.removeFirst(3)
        }

        if baseDir.isEmpty || baseDir == "." { return result }
        return "\(baseDir)/\(result)"
    }
}

// MARK: - ParsedEPUB Result
struct ParsedEPUB {
    let title: String
    let author: String
    let coverImageData: Data?
    let chapters: [Chapter]
    let spine: [String]
    let manifest: [String: String]
    let baseDir: String
    let zip: ZipReader
}

// MARK: - EPUB Errors
enum EPUBError: LocalizedError {
    case missingContainerXML
    case missingOPF(String)
    case invalidOPF(String)
    case extractionFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingContainerXML:   return "EPUB 中找不到 META-INF/container.xml"
        case .missingOPF(let path):  return "EPUB 中找不到 OPF 文件: \(path)"
        case .invalidOPF(let msg):   return "OPF 文件解析失败: \(msg)"
        case .extractionFailed(let msg): return "内容提取失败: \(msg)"
        }
    }
}
