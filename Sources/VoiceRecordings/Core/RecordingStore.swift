//
//  RecordingStore.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//
//  The Voice Memos library: CloudRecordings.db (Core Data, mirrored to
//  iCloud) read from a private copy (swift-sqlite-reader's snapshot), and each recording's .m4a read for the
//  transcript Voice Memos stores inside it. Nothing in Voice Memos' container
//  is ever written; transcripts made on this Mac are kept in
//  ``RecordingLocations/transcripts``.
//

import Foundation
import SQLiteReader

/// A Mac's voice recordings, read-only.
public struct RecordingStore: Sendable {

    /// Where everything is.
    public let locations: RecordingLocations

    public init(locations: RecordingLocations = RecordingLocations()) {
        self.locations = locations
    }

    // MARK: Recordings

    /// Every recording, newest first — Recently Deleted included, flagged.
    ///
    /// - Parameter readFiles: also open each file for its device (one small
    ///   read per recording); off, ``Recording/device`` is `.unknown`.
    public func recordings(readFiles: Bool = true) throws(RecordingsError) -> [Recording] {
        let database = try open()
        let present = database.columns(of: "ZCLOUDRECORDING")
        guard !present.isEmpty else { throw .unreadable(locations.database.path, reason: "no ZCLOUDRECORDING table") }
        let folders = try folderNames(database)
        let wanted = ["ZUNIQUEID", "ZENCRYPTEDTITLE", "ZCUSTOMLABEL", "ZDATE", "ZDURATION", "ZLOCALDURATION", "ZPATH",
                      "ZFOLDER", "ZEVICTIONDATE", "ZFLAGS", "ZSHAREDFLAGS", "ZSKIPSILENCEENABLED", "ZSTUDIOMIXENABLED",
                      "ZPLAYBACKPOSITION", "ZPLAYBACKSPEED", "Z_PK"]
        let select = wanted.map { present.contains($0) ? $0 : "NULL" }.joined(separator: ", ")
        var recordings: [Recording] = []
        do {
            try database.query("SELECT \(select) FROM ZCLOUDRECORDING ORDER BY ZDATE DESC") { row in
                guard let seconds = row[3].double else { return }
                let id = row[0].nonEmptyString ?? "row-\(row[15].truncatedInt ?? 0)"
                let flags = row[9].truncatedInt ?? 0, shared = row[10].truncatedInt ?? 0
                let file = row[6].nonEmptyString.map { locations.recordings.appendingPathComponent($0) }
                let exists = file.map { FileManager.default.fileExists(atPath: $0.path) } ?? false
                recordings.append(Recording(
                    id: id,
                    title: row[1].nonEmptyString ?? row[2].nonEmptyString ?? "Untitled",
                    date: Date(timeIntervalSinceReferenceDate: seconds),
                    duration: max(0, row[4].double ?? row[5].double ?? 0),
                    file: file?.path,
                    fileExists: exists,
                    folder: row[7].truncatedInt.flatMap { folders[$0] },
                    deleted: row[8].double.map { Date(timeIntervalSinceReferenceDate: $0) },
                    favorite: RecordingFlags.has(shared, RecordingFlags.favorite),
                    enhanced: RecordingFlags.has(shared, RecordingFlags.enhanced),
                    musicMemo: RecordingFlags.has(shared, RecordingFlags.musicMemo),
                    recordedOnWatch: RecordingFlags.has(flags, RecordingFlags.recordedOnWatch) || RecordingFlags.has(shared, RecordingFlags.watchOS),
                    audioInICloudOnly: RecordingFlags.has(flags, RecordingFlags.audioNeedsDownload) || (file != nil && !exists),
                    transcribed: RecordingFlags.has(flags, RecordingFlags.hasBeenTranscribed),
                    hasTranscript: RecordingFlags.has(flags, RecordingFlags.transcriptExists),
                    layered: RecordingFlags.has(flags, RecordingFlags.multipleTracks),
                    spatial: RecordingFlags.has(flags, RecordingFlags.spatial),
                    manuallyRenamed: RecordingFlags.has(flags, RecordingFlags.manuallyRenamed),
                    skipSilence: (row[11].truncatedInt ?? 0) != 0,
                    studioVoice: (row[12].truncatedInt ?? 0) != 0,
                    playbackPosition: row[13].double.flatMap { $0 > 0 ? $0 : nil },
                    playbackSpeed: row[14].double,
                    flags: flags,
                    sharedFlags: shared
                ))
            }
        } catch { throw RecordingsError(error) }
        guard readFiles else { return recordings }
        return recordings.map { recording in
            guard recording.fileExists, let path = recording.file, let data = Self.contents(of: path) else { return recording }
            var read = recording
            let facts = TranscriptParsing.facts(data)
            read.device = facts.device
            read.recorder = facts.recorder
            return read
        }
    }

    /// The recording an id, an id's first characters, or a title means.
    ///
    /// An exact id wins; then a unique id prefix; then a title, exact before
    /// contained, ignoring case. Two equally good matches are refused with
    /// both (`ambiguous` carries them) rather than one picked.
    public func recording(matching query: String, in recordings: [Recording]) throws(RecordingsError) -> Recording {
        try RecordingMatching.one(query, in: recordings)
    }

    /// The user folders, by rank.
    public func folders() throws(RecordingsError) -> [RecordingFolder] {
        let database = try open()
        let columns = database.columns(of: "ZFOLDER")
        guard !columns.isEmpty else { return [] }
        var folders: [RecordingFolder] = []
        do {
            try database.query("SELECT ZUUID, ZENCRYPTEDNAME, ZCOUNTOFRECORDINGS, ZRANK FROM ZFOLDER ORDER BY ZRANK") { row in
                folders.append(RecordingFolder(id: row[0].nonEmptyString, name: row[1].nonEmptyString ?? "Untitled folder",
                                               recordings: row[2].truncatedInt ?? 0, rank: row[3].truncatedInt))
            }
        } catch { throw RecordingsError(error) }
        return folders
    }

    func folderNames(_ database: SQLiteReader) throws(RecordingsError) -> [Int: String] {
        guard !database.columns(of: "ZFOLDER").isEmpty else { return [:] }
        var names: [Int: String] = [:]
        do {
            try database.query("SELECT Z_PK, ZENCRYPTEDNAME FROM ZFOLDER") { row in
                if let key = row[0].truncatedInt, let name = row[1].nonEmptyString { names[key] = name }
            }
        } catch { throw RecordingsError(error) }
        return names
    }

    /// A private copy of the store and its log, deleted when the reader goes:
    /// the live store is never opened.
    private func open() throws(RecordingsError) -> SQLiteReader {
        do { return try SQLiteReader(path: locations.database, opening: .snapshot) } catch { throw RecordingsError(error) }
    }

    // MARK: Transcripts

    /// The best transcript: Voice Memos' own, else one made on this Mac, else `nil`.
    public func transcript(for recording: Recording) throws(RecordingsError) -> Transcript? {
        if let own = try voiceMemosTranscript(for: recording) { return own }
        return savedTranscript(for: recording)
    }

    /// The transcript Voice Memos stored inside the file.
    public func voiceMemosTranscript(for recording: Recording) throws(RecordingsError) -> Transcript? {
        guard recording.fileExists, let path = recording.file else { return nil }
        switch FileChecks.access(path) {
        case .readable: break
        case .missing: return nil
        case .refused: throw .needsFullDiskAccess(path)
        }
        guard let data = FileManager.default.contents(atPath: path) else { throw .unreadable(path, reason: "the file could not be read") }
        return TranscriptParsing.facts(data).transcript
    }

    /// A transcript made on this Mac, if one was saved.
    public func savedTranscript(for recording: Recording) -> Transcript? {
        guard let data = FileManager.default.contents(atPath: savedTranscriptURL(for: recording).path) else { return nil }
        return try? JSONDecoder().decode(Transcript.self, from: data)
    }

    /// Keeps a transcript made on this Mac, in this library's own folder.
    public func save(_ transcript: Transcript, for recording: Recording) throws(RecordingsError) {
        let url = savedTranscriptURL(for: recording)
        do {
            try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.sortedKeys]
            try encoder.encode(transcript).write(to: url, options: .atomic)
        } catch {
            throw .unreadable(url.path, reason: error.localizedDescription)
        }
    }

    /// Where a recording's own transcript is kept: `<transcripts>/<id>.json`.
    public func savedTranscriptURL(for recording: Recording) -> URL {
        let safe = recording.id.filter { $0.isLetter || $0.isNumber || $0 == "-" }
        return locations.transcripts.appendingPathComponent("\(safe.isEmpty ? "recording" : safe).json")
    }

    /// The audio file, if it is on this Mac.
    public func audio(for recording: Recording) throws(RecordingsError) -> URL {
        guard recording.fileExists, let path = recording.file else { throw .audioNotHere(recording.title) }
        return URL(fileURLWithPath: path)
    }

    /// A recording's file, whole. Voice Memos writes the metadata boxes
    /// (`moov`, with the transcript) after the audio, so there is no shorter
    /// read that reaches them; an hour of AAC is tens of megabytes.
    static func contents(of path: String) -> Data? {
        guard let handle = FileHandle(forReadingAtPath: path) else { return nil }
        defer { try? handle.close() }
        return try? handle.readToEnd()
    }
}

/// Picking the one recording a query means.
enum RecordingMatching {

    static func one(_ query: String, in recordings: [Recording]) throws(RecordingsError) -> Recording {
        let wanted = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if let exact = recordings.first(where: { $0.id.caseInsensitiveCompare(wanted) == .orderedSame }) { return exact }
        for pass in [
            recordings.filter { $0.id.lowercased().hasPrefix(wanted.lowercased()) && wanted.count >= 4 },
            recordings.filter { $0.title.caseInsensitiveCompare(wanted) == .orderedSame },
            recordings.filter { $0.title.range(of: wanted, options: [.caseInsensitive, .diacriticInsensitive]) != nil },
        ] {
            if pass.count == 1 { return pass[0] }
            if pass.count > 1 { throw .notFound("\(wanted) — it matches \(pass.count) recordings: " + pass.prefix(5).map { "\($0.title) (\($0.id.prefix(8)))" }.joined(separator: ", ")) }
        }
        throw .notFound(wanted)
    }
}
