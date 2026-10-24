//
//  Transcript.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// A recording's words, with when each was said.
public struct Transcript: Codable, Sendable, Hashable {

    /// Who made it.
    public var source: TranscriptSource

    /// The language it was transcribed in (`en_GB`).
    public var locale: String?

    /// Every word (or run of text) with its time range, in order. Spacing
    /// and punctuation are kept inside the runs, so joining them gives the text.
    public var words: [TimedWord]

    /// Spoken passages with a speaker, when the transcript was made with
    /// speaker labels; empty otherwise.
    public var turns: [SpeakerTurn]

    public init(source: TranscriptSource, locale: String? = nil, words: [TimedWord], turns: [SpeakerTurn] = []) {
        self.source = source
        self.locale = locale
        self.words = words
        self.turns = turns
    }
}

/// A piece of text and when it was said, in seconds from the start.
public struct TimedWord: Codable, Sendable, Hashable {
    public var text: String
    public var start: Double?
    public var end: Double?

    public init(text: String, start: Double? = nil, end: Double? = nil) {
        self.text = text
        self.start = start
        self.end = end
    }
}

/// A passage by one speaker.
public struct SpeakerTurn: Codable, Sendable, Hashable {

    /// `Speaker 1`, `Speaker 2`… — diarisation tells voices apart, not who they are.
    public var speaker: String
    public var start: Double
    public var end: Double
    public var text: String

    public init(speaker: String, start: Double, end: Double, text: String) {
        self.speaker = speaker
        self.start = start
        self.end = end
        self.text = text
    }
}

/// A sentence-sized stretch of a transcript.
public struct TranscriptLine: Codable, Sendable, Hashable {
    public var start: Double
    public var end: Double
    public var text: String
    public var speaker: String?

    public init(start: Double, end: Double, text: String, speaker: String? = nil) {
        self.start = start
        self.end = end
        self.text = text
        self.speaker = speaker
    }
}

/// Where a search matched.
public struct RecordingMatch: Codable, Sendable, Hashable {
    public var recordingID: String
    public var title: String
    public var date: Date

    /// `title` or `transcript`.
    public var field: String

    /// The words around the match.
    public var snippet: String

    /// When the match is said, in seconds — for a transcript match with timings.
    public var at: Double?

    public init(recordingID: String, title: String, date: Date, field: String, snippet: String, at: Double? = nil) {
        self.recordingID = recordingID
        self.title = title
        self.date = date
        self.field = field
        self.snippet = snippet
        self.at = at
    }
}

/// Totals over a set of recordings.
public struct RecordingStats: Codable, Sendable, Hashable {
    public var recordings: Int
    public var seconds: Double
    public var averageSeconds: Double
    public var longestSeconds: Double
    public var longestID: String?
    public var first: Date?
    public var last: Date?
    public var withTranscript: Int
    public var transcribedSilent: Int
    public var notTranscribed: Int
    public var favorites: Int
    public var deleted: Int
    public var inICloudOnly: Int
    public var byDevice: [String: Int]
    public var byFolder: [String: Int]
    public var byMonth: [String: Int]

    public init(
        recordings: Int, seconds: Double, averageSeconds: Double, longestSeconds: Double, longestID: String?,
        first: Date?, last: Date?, withTranscript: Int, transcribedSilent: Int, notTranscribed: Int,
        favorites: Int, deleted: Int, inICloudOnly: Int, byDevice: [String: Int], byFolder: [String: Int],
        byMonth: [String: Int]
    ) {
        self.recordings = recordings
        self.seconds = seconds
        self.averageSeconds = averageSeconds
        self.longestSeconds = longestSeconds
        self.longestID = longestID
        self.first = first
        self.last = last
        self.withTranscript = withTranscript
        self.transcribedSilent = transcribedSilent
        self.notTranscribed = notTranscribed
        self.favorites = favorites
        self.deleted = deleted
        self.inICloudOnly = inICloudOnly
        self.byDevice = byDevice
        self.byFolder = byFolder
        self.byMonth = byMonth
    }
}
