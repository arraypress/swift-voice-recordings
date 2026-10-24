//
//  RecordingLocations.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Where a home folder keeps the Voice Memos library — a real home, or a fixture one.
public struct RecordingLocations: Sendable, Hashable {

    /// The store: CloudRecordings.db.
    public var database: URL

    /// The folder the recordings' files sit in (the store's own).
    public var recordings: URL

    /// Where transcripts made on this Mac are kept — never inside Voice
    /// Memos' container, which this library does not write.
    public var transcripts: URL

    public init(database: URL, recordings: URL, transcripts: URL) {
        self.database = database
        self.recordings = recordings
        self.transcripts = transcripts
    }

    /// The library under `home`, where macOS 26 and 27 keep it.
    public init(home: URL = FileManager.default.homeDirectoryForCurrentUser) {
        let recordings = home.appendingPathComponent(
            "Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings", isDirectory: true)
        self.init(
            database: recordings.appendingPathComponent("CloudRecordings.db"),
            recordings: recordings,
            transcripts: home.appendingPathComponent("Library/Application Support/voice-recordings/transcripts", isDirectory: true)
        )
    }
}
