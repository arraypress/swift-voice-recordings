//
//  MP4Atoms.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//
//  Just enough of the MP4 box format to find what Voice Memos writes into a
//  recording: `moov/trak/udta/tsrp` (the transcript, as JSON),
//  `moov/udta/meta/ilst/©too` (the app and device that recorded it) and the
//  iTunes freeform `----` atom named `voice-memo-uuid`. MEASURED layout on
//  macOS 27.0.1 and iOS 27.0.1 recordings.
//

import Foundation

/// Reading MP4 boxes.
public enum MP4Atoms {

    /// One box: its type, path from the root, and the byte range of its payload.
    public struct Box: Sendable, Hashable {
        public var type: String
        public var path: String
        public var payload: Range<Int>
    }

    /// Containers whose payload is more boxes. `meta` carries four bytes of
    /// version and flags before its children.
    static let containers: Set<String> = ["moov", "trak", "udta", "mdia", "minf", "stbl", "meta", "ilst", "edts", "dinf"]

    /// Every box in `data`, depth first. Malformed sizes end the walk at that
    /// level rather than reading past the data.
    public static func boxes(_ data: Data) -> [Box] {
        var found: [Box] = []
        walk(data, from: data.startIndex, to: data.endIndex, path: "", into: &found)
        return found
    }

    static func walk(_ data: Data, from start: Int, to end: Int, path: String, into found: inout [Box]) {
        var offset = start
        while offset + 8 <= end {
            var size = Int(uint32(data, offset))
            var header = 8
            if size == 1 {
                guard offset + 16 <= end else { return }
                size = Int(clamping: uint64(data, offset + 8))
                header = 16
            } else if size == 0 {
                size = end - offset
            }
            guard size >= header, offset + size <= end else { return }
            // Latin-1, so Apple's `©too` (0xA9 't' 'o' 'o') reads as itself.
            let latin = String(data: data[(offset + 4)..<(offset + 8)], encoding: .isoLatin1) ?? "????"
            let boxPath = path + "/" + latin
            found.append(Box(type: latin, path: boxPath, payload: (offset + header)..<(offset + size)))
            if containers.contains(latin) {
                let children = offset + header + (latin == "meta" ? 4 : 0)
                walk(data, from: children, to: offset + size, path: boxPath, into: &found)
            }
            offset += size
        }
    }

    /// The payload of the first box of `type`.
    public static func payload(_ type: String, in data: Data, boxes: [Box]? = nil) -> Data? {
        guard let box = (boxes ?? self.boxes(data)).first(where: { $0.type == type }) else { return nil }
        return data[box.payload]
    }

    /// The string in an `ilst` item's `data` child (8 bytes of type and
    /// locale, then the text), e.g. `©too`.
    public static func itemString(_ type: String, in data: Data, boxes: [Box]? = nil) -> String? {
        let all = boxes ?? self.boxes(data)
        guard let item = all.first(where: { $0.type == type }) else { return nil }
        var inner: [Box] = []
        walk(data, from: item.payload.lowerBound, to: item.payload.upperBound, path: item.path, into: &inner)
        guard let value = inner.first(where: { $0.type == "data" }), value.payload.count > 8 else { return nil }
        return String(data: data[(value.payload.lowerBound + 8)..<value.payload.upperBound], encoding: .utf8)
    }

    /// The value of an iTunes freeform (`----`) item by its `name`.
    public static func freeform(_ name: String, in data: Data, boxes: [Box]? = nil) -> String? {
        let all = boxes ?? self.boxes(data)
        for item in all where item.type == "----" {
            var inner: [Box] = []
            walk(data, from: item.payload.lowerBound, to: item.payload.upperBound, path: item.path, into: &inner)
            guard let named = inner.first(where: { $0.type == "name" }), named.payload.count > 4,
                  String(data: data[(named.payload.lowerBound + 4)..<named.payload.upperBound], encoding: .utf8) == name,
                  let value = inner.first(where: { $0.type == "data" }), value.payload.count > 8 else { continue }
            return String(data: data[(value.payload.lowerBound + 8)..<value.payload.upperBound], encoding: .utf8)
        }
        return nil
    }

    static func uint32(_ data: Data, _ offset: Int) -> UInt32 {
        data[offset..<(offset + 4)].reduce(0) { $0 << 8 | UInt32($1) }
    }

    static func uint64(_ data: Data, _ offset: Int) -> UInt64 {
        data[offset..<(offset + 8)].reduce(0) { $0 << 8 | UInt64($1) }
    }
}
