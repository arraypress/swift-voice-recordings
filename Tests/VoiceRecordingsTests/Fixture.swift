//
//  Fixture.swift
//  VoiceRecordingsTests
//
//  Created by David Sherlock on 2026.
//
//  A fixture home with a CloudRecordings.db in the real schema's shape and
//  recordings built box by box the way Voice Memos writes them — every
//  title and word invented.
//

import Foundation
import SQLite3
import VoiceRecordings

struct FixtureHome {

    let root = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("voice-recordings-tests-\(UUID().uuidString.prefix(8))")
    var locations: RecordingLocations { RecordingLocations(home: root) }
    var store: RecordingStore { RecordingStore(locations: locations) }

    init() throws {
        try FileManager.default.createDirectory(at: locations.recordings, withIntermediateDirectories: true)
    }

    func remove() {
        _ = try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: locations.recordings.path)
        try? FileManager.default.removeItem(at: root)
    }

    /// One row of ZCLOUDRECORDING.
    struct Row {
        var key: Int
        var id: String
        var title: String
        var date: Double
        var duration: Double
        var path: String?
        var flags = 4
        var shared = 0
        var folder: Int?
        var deleted: Double?
    }

    func database(_ rows: [Row], folders: [(key: Int, name: String)] = [], walOnly: [Row] = []) throws {
        var db: OpaquePointer?
        guard sqlite3_open(locations.database.path, &db) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown) }
        defer { sqlite3_close(db) }
        func exec(_ sql: String) throws {
            guard sqlite3_exec(db, sql, nil, nil, nil) == SQLITE_OK else { throw CocoaError(.fileWriteUnknown, userInfo: [NSDebugDescriptionErrorKey: sql]) }
        }
        func insert(_ row: Row) -> String {
            let quote = { (text: String?) in text.map { "'\($0.replacingOccurrences(of: "'", with: "''"))'" } ?? "NULL" }
            return """
                INSERT INTO ZCLOUDRECORDING (Z_PK, ZUNIQUEID, ZENCRYPTEDTITLE, ZCUSTOMLABEL, ZDATE, ZDURATION, ZPATH, ZFLAGS, ZSHAREDFLAGS,
                  ZFOLDER, ZEVICTIONDATE, ZSKIPSILENCEENABLED, ZPLAYBACKSPEED)
                VALUES (\(row.key), \(quote(row.id)), \(quote(row.title)), \(quote(row.title)), \(row.date), \(row.duration), \(quote(row.path)),
                  \(row.flags), \(row.shared), \(row.folder.map(String.init) ?? "NULL"), \(row.deleted.map { "\($0)" } ?? "NULL"), 0, 1.0)
                """
        }
        try exec("PRAGMA journal_mode=WAL")
        try exec("""
            CREATE TABLE ZCLOUDRECORDING (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZAUDIOFUTUREFLAGS INTEGER, ZFLAGS INTEGER,
              ZSHAREDFLAGS INTEGER, ZSILENCEREMOVERENABLED INTEGER, ZSKIPSILENCEENABLED INTEGER, ZSTUDIOMIXENABLED INTEGER, ZFOLDER INTEGER,
              ZDATE TIMESTAMP, ZDURATION FLOAT, ZEVICTIONDATE TIMESTAMP, ZLOCALDURATION FLOAT, ZPLAYBACKPOSITION FLOAT, ZPLAYBACKSPEED FLOAT,
              ZCUSTOMLABEL VARCHAR, ZENCRYPTEDTITLE VARCHAR, ZPATH VARCHAR, ZUNIQUEID VARCHAR)
            """)
        try exec("CREATE TABLE ZFOLDER (Z_PK INTEGER PRIMARY KEY, Z_ENT INTEGER, Z_OPT INTEGER, ZCOUNTOFRECORDINGS INTEGER, ZRANK INTEGER, ZENCRYPTEDNAME VARCHAR, ZUUID VARCHAR)")
        for folder in folders {
            try exec("INSERT INTO ZFOLDER VALUES (\(folder.key), 1, 1, \(rows.filter { $0.folder == folder.key }.count), \(folder.key), '\(folder.name)', 'F-\(folder.key)')")
        }
        for row in rows { try exec(insert(row)) }
        try exec("PRAGMA wal_checkpoint(TRUNCATE)")
        try exec("PRAGMA wal_autocheckpoint=0")
        for row in walOnly { try exec(insert(row)) }
    }

    /// Writes a recording file the way Voice Memos lays one out.
    func file(_ name: String, words: [(String, Double, Double)]?, recorder: String, uuid: String) throws {
        try Self.m4a(words: words, recorder: recorder, uuid: uuid).write(to: locations.recordings.appendingPathComponent(name))
    }

    // MARK: Building MP4 boxes

    static func box(_ type: String, _ payload: Data) -> Data {
        var size = UInt32(8 + payload.count).bigEndian
        var data = Data(bytes: &size, count: 4)
        data += type.data(using: .isoLatin1)!
        return data + payload
    }

    static func item(_ text: String) -> Data {
        box("data", Data([0, 0, 0, 1, 0, 0, 0, 0]) + Data(text.utf8))
    }

    /// `ftyp`, `mdat`, then `moov` (audio first, as Voice Memos writes it).
    static func m4a(words: [(String, Double, Double)]?, recorder: String, uuid: String) -> Data {
        var runs: [Any] = []
        var table: [[String: Any]] = []
        for (index, word) in (words ?? []).enumerated() {
            runs += [word.0, index]
            table.append(["timeRange": [word.1, word.2]])
        }
        let attributed: [String: Any] = words == nil ? [:] : ["runs": runs, "attributeTable": table]
        let json = try! JSONSerialization.data(withJSONObject: ["locale": ["identifier": "en_GB"], "attributedString": attributed])
        let freeform = box("----", box("mean", Data([0, 0, 0, 0]) + Data("com.apple.iTunes".utf8))
                                 + box("name", Data([0, 0, 0, 0]) + Data("voice-memo-uuid".utf8))
                                 + item(uuid))
        let ilst = box("ilst", freeform + box("©too", item(recorder)))
        let meta = box("meta", Data([0, 0, 0, 0]) + box("hdlr", Data(repeating: 0, count: 24)) + ilst)
        let trak = box("trak", box("tkhd", Data(repeating: 0, count: 84)) + box("udta", box("tsrp", json)))
        let moov = box("moov", box("mvhd", Data(repeating: 0, count: 100)) + trak + box("udta", meta))
        return box("ftyp", Data("M4A ".utf8) + Data(repeating: 0, count: 8)) + box("mdat", Data(repeating: 0xAB, count: 512)) + moov
    }
}

/// Core Data seconds for a local date.
func coreData(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Double {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day, hour: hour))!.timeIntervalSinceReferenceDate
}
