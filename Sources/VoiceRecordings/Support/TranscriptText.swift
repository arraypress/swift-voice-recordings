//
//  TranscriptText.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//
//  A transcript as people and other tools want it: one text, sentence-sized
//  lines with times, subtitles, or overlapping chunks small enough for an
//  on-device model. Pure functions over ``Transcript``.
//

import Foundation
import SubtitleKit

/// Turning transcripts into text.
public enum TranscriptText {

    /// The whole text: the runs joined, or the speaker turns one per line.
    public static func plain(_ transcript: Transcript) -> String {
        if !transcript.turns.isEmpty {
            return transcript.turns.map { "\($0.speaker): \($0.text)" }.joined(separator: "\n")
        }
        return collapse(transcript.words.map(\.text).joined())
    }

    /// The transcript in lines: a speaker's turns as they are, otherwise
    /// words gathered into sentences — a line ends at `.`, `?` or `!`, at a
    /// pause of `pause` seconds or more, or once it is `maxSeconds` long.
    public static func lines(_ transcript: Transcript, pause: Double = 1.2, maxSeconds: Double = 12) -> [TranscriptLine] {
        if !transcript.turns.isEmpty {
            return transcript.turns.map { TranscriptLine(start: $0.start, end: $0.end, text: $0.text, speaker: $0.speaker) }
        }
        var lines: [TranscriptLine] = []
        var text = "", start: Double?, end: Double?
        func flush() {
            let trimmed = collapse(text)
            if !trimmed.isEmpty { lines.append(TranscriptLine(start: start ?? end ?? 0, end: end ?? start ?? 0, text: trimmed)) }
            text = ""; start = nil; end = nil
        }
        for word in transcript.words {
            if let previous = end, let next = word.start, next - previous >= pause { flush() }
            text += word.text
            start = start ?? word.start
            end = word.end ?? end
            let trimmed = word.text.trimmingCharacters(in: .whitespaces)
            let sentenceEnds = trimmed.hasSuffix(".") || trimmed.hasSuffix("?") || trimmed.hasSuffix("!")
            let tooLong = (end ?? 0) - (start ?? 0) >= maxSeconds
            if sentenceEnds || tooLong { flush() }
        }
        flush()
        return lines
    }

    /// Lines with their times, `[01:02] text` (speaker first when known).
    public static func timed(_ transcript: Transcript) -> String {
        lines(transcript).map { line in
            "[\(clock(line.start))] " + (line.speaker.map { "\($0): " } ?? "") + line.text
        }.joined(separator: "\n")
    }

    /// Subtitles, SRT or WebVTT.
    public static func subtitles(_ transcript: Transcript, format: SubtitleFormat) -> String {
        let cues = lines(transcript).map { line in
            SubtitleCue(start: line.start, end: max(line.end, line.start + 0.5), text: (line.speaker.map { "\($0): " } ?? "") + line.text)
        }
        return SubtitleWriter.render(cues, format: format)
    }

    /// SubRip subtitles.
    public static func srt(_ transcript: Transcript) -> String { subtitles(transcript, format: .srt) }

    /// WebVTT subtitles.
    public static func vtt(_ transcript: Transcript) -> String { subtitles(transcript, format: .vtt) }

    /// The text cut into pieces of at most `limit` characters at line
    /// boundaries, each starting with its time — for a model with a small
    /// context. A single line longer than the limit is its own piece.
    public static func chunks(_ transcript: Transcript, limit: Int = 6_000) -> [String] {
        var pieces: [String] = []
        var current = ""
        for line in lines(transcript) {
            let entry = "[\(clock(line.start))] " + (line.speaker.map { "\($0): " } ?? "") + line.text + "\n"
            if !current.isEmpty && current.count + entry.count > limit {
                pieces.append(current)
                current = ""
            }
            current += entry
        }
        if !current.isEmpty { pieces.append(current) }
        return pieces
    }

    /// `m:ss`, or `h:mm:ss` past an hour.
    public static func clock(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded(.down))
        if total >= 3_600 { return String(format: "%d:%02d:%02d", total / 3_600, (total % 3_600) / 60, total % 60) }
        return String(format: "%d:%02d", total / 60, total % 60)
    }

    /// Runs of whitespace as one space, trimmed.
    static func collapse(_ text: String) -> String {
        text.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}
