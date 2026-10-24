//
//  TranscriptSource.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

/// Where a transcript came from.
public enum TranscriptSource: String, Codable, Sendable {

    /// Voice Memos' own, stored inside the recording's file.
    case voiceMemos

    /// One made on this Mac afterwards and kept beside the store's copy.
    case transcribed
}
