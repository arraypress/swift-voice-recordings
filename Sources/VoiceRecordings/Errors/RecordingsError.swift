//
//  RecordingsError.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong reading a Mac's voice recordings.
public enum RecordingsError: Error, Equatable, Sendable, LocalizedError {

    /// macOS refused to let this process read the store — what a missing
    /// Full Disk Access grant looks like. Carries the path.
    case needsFullDiskAccess(String)

    /// No store: Voice Memos has never run on this Mac. Carries the path.
    case noStore(String)

    /// The store or a recording is there but could not be understood.
    case unreadable(String, reason: String)

    /// No recording has this id or title.
    case notFound(String)

    /// The recording's audio is not on this Mac — it is only in iCloud,
    /// or the file is missing. Carries the recording's title.
    case audioNotHere(String)

    /// A sentence a person can act on.
    public var errorDescription: String? {
        switch self {
        case .needsFullDiskAccess(let path):
            "Not allowed to read \(path) — macOS keeps Voice Memos behind Full Disk Access"
        case .noStore(let path):
            "Nothing at \(path) — Voice Memos has not run on this Mac"
        case .unreadable(let path, let reason):
            "Could not read \(path): \(reason)"
        case .notFound(let query):
            "No recording matches \(query)"
        case .audioNotHere(let title):
            "The audio of \(title) is not on this Mac (it is only in iCloud) — open it once in Voice Memos to download it"
        }
    }
}
