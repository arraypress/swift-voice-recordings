//
//  RecordingSearch.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//
//  Finding words in titles and transcripts — ignoring case and accents —
//  and, in a transcript with timings, WHEN they were said. A match must
//  start a word ("art" does not find "start"); it may stop inside one
//  ("deliver" finds "delivery").
//

import Foundation

/// Searching recordings.
public enum RecordingSearch {

    /// Every match of `query` in the titles and transcripts, a recording's
    /// title match first, then its transcript matches in time order.
    ///
    /// - Parameter transcripts: by recording id; recordings without one are
    ///   searched by title only.
    public static func matches(_ query: String, in recordings: [Recording], transcripts: [String: Transcript],
                               context: Int = 60) -> [RecordingMatch] {
        let needle = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !needle.isEmpty else { return [] }
        var found: [RecordingMatch] = []
        for recording in recordings {
            if startsAWord(fold(needle), in: fold(recording.title)) {
                found.append(RecordingMatch(recordingID: recording.id, title: recording.title, date: recording.date,
                                            field: "title", snippet: recording.title))
            }
            guard let transcript = transcripts[recording.id] else { continue }
            found += transcriptMatches(needle, transcript: transcript, recording: recording, context: context)
        }
        return found
    }

    /// The matches inside one transcript, each with the time of the word
    /// the match starts in.
    static func transcriptMatches(_ needle: String, transcript: Transcript, recording: Recording, context: Int) -> [RecordingMatch] {
        // The text, and which word each character came from.
        var text = ""
        var owners: [Int] = []
        let pieces: [(text: String, start: Double?)] = transcript.turns.isEmpty
            ? transcript.words.map { ($0.text, $0.start) }
            : transcript.turns.map { (" " + $0.text, $0.start) }
        for (index, piece) in pieces.enumerated() {
            text += piece.text
            owners += Array(repeating: index, count: piece.text.count)
        }
        let folded = Array(fold(text))
        let wanted = Array(fold(needle))
        // Folding keeps one character per character for ordinary text; when
        // it does not (a ligature), positions are still clamped, never read past.
        guard wanted.count <= folded.count else { return [] }
        let characters = Array(text)
        var found: [RecordingMatch] = []
        var position = 0
        while position + wanted.count <= folded.count {
            let startsWord = position == 0 || !(folded[position - 1].isLetter || folded[position - 1].isNumber)
            if startsWord && Array(folded[position..<(position + wanted.count)]) == wanted {
                let from = max(0, position - context), to = min(characters.count, position + wanted.count + context)
                let snippet = (from > 0 ? "…" : "") + String(characters[min(from, characters.count)..<to]).trimmingCharacters(in: .whitespaces)
                    + (to < characters.count ? "…" : "")
                let owner = owners.indices.contains(position) ? owners[position] : nil
                found.append(RecordingMatch(recordingID: recording.id, title: recording.title, date: recording.date,
                                            field: "transcript", snippet: TranscriptText.collapse(snippet),
                                            at: owner.flatMap { pieces[$0].start }))
                position += wanted.count
            } else {
                position += 1
            }
        }
        return found
    }

    /// Whether `needle` occurs in `text` at the start of a word.
    static func startsAWord(_ needle: String, in text: String) -> Bool {
        var searchRange = text.startIndex..<text.endIndex
        while let found = text.range(of: needle, range: searchRange) {
            if found.lowerBound == text.startIndex { return true }
            let before = text[text.index(before: found.lowerBound)]
            if !(before.isLetter || before.isNumber) { return true }
            searchRange = found.upperBound..<text.endIndex
        }
        return false
    }

    /// Lower-cased with accents and width differences removed.
    static func fold(_ text: String) -> String {
        text.folding(options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive], locale: nil)
    }
}
