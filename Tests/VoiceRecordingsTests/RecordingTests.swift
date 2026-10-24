//
//  RecordingTests.swift
//  VoiceRecordingsTests
//
//  Created by David Sherlock on 2026.
//

import Foundation
import SubtitleKit
import Testing
@testable import VoiceRecordings

let words: [(String, Double, Double)] = [
    ("Pick", 0.5, 0.8), (" up", 0.8, 1.0), (" the", 1.0, 1.1), (" parcel", 1.1, 1.6), (" on", 1.6, 1.7), (" Friday.", 1.7, 2.3),
    (" Then", 4.5, 4.8), (" call", 4.8, 5.1), (" the", 5.1, 5.2), (" café", 5.2, 5.7), (" back?", 5.7, 6.2),
]

@Suite(.serialized)
struct StoreTests {

    @Test func recordingsAreDecodedWithTheMeasuredFlags() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.database([
            .init(key: 1, id: "AAAA1111-0000-0000-0000-000000000001", title: "Shopping", date: coreData(2026, 10, 1), duration: 6.4,
                  path: "a.m4a", flags: 1540, shared: 1, folder: 7),
            .init(key: 2, id: "BBBB2222-0000-0000-0000-000000000002", title: "Silence", date: coreData(2026, 10, 2), duration: 4,
                  path: "b.m4a", flags: 516, shared: 2, deleted: coreData(2026, 10, 3)),
            .init(key: 3, id: "CCCC3333-0000-0000-0000-000000000003", title: "Cloud only", date: coreData(2026, 9, 1), duration: 30,
                  path: "gone.m4a", flags: 2 | 4 | 64 | 2048, shared: 4),
        ], folders: [(7, "Errands")])
        try home.file("a.m4a", words: words, recorder: "com.apple.VoiceMemos (iPhone Version 27.0.1 (Build 24A446))", uuid: "AAAA1111-0000-0000-0000-000000000001")
        try home.file("b.m4a", words: nil, recorder: "com.apple.VoiceMemos (iPad Version 27.0 (Build 26A428))", uuid: "BBBB2222-0000-0000-0000-000000000002")

        let all = try home.store.recordings()
        #expect(all.map(\.title) == ["Silence", "Shopping", "Cloud only"])
        let shopping = all[1]
        // One bit each: favourite is bit 0, enhanced bit 1 (measured through Apple's own class).
        #expect(shopping.transcribed && shopping.hasTranscript && shopping.favorite && !shopping.enhanced)
        #expect(shopping.folder == "Errands" && shopping.device == .iPhone && shopping.fileExists)
        let silence = all[0]
        #expect(silence.transcribed && !silence.hasTranscript && silence.deleted != nil && silence.device == .iPadOrMac)
        #expect(silence.enhanced && !silence.favorite)
        let cloud = all[2]
        #expect(cloud.audioInICloudOnly && cloud.recordedOnWatch && cloud.layered && cloud.musicMemo && !cloud.fileExists)
        #expect(cloud.device == .unknown)

        let transcript = try #require(try home.store.transcript(for: shopping))
        #expect(transcript.source == .voiceMemos && transcript.locale == "en_GB" && transcript.words.count == 11)
        #expect(TranscriptText.plain(transcript) == "Pick up the parcel on Friday. Then call the café back?")
        #expect(try home.store.transcript(for: silence) == nil)
        #expect(throws: RecordingsError.audioNotHere("Cloud only")) { try home.store.audio(for: cloud) }
        #expect(try home.store.folders() == [RecordingFolder(id: "F-7", name: "Errands", recordings: 1, rank: 7)])
    }

    @Test func recentRowsInTheWriteAheadLogAreRead() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.database([.init(key: 1, id: "OLD", title: "Old", date: coreData(2026, 1, 1), duration: 1, path: nil)],
                          walOnly: [.init(key: 2, id: "NEW", title: "New", date: coreData(2026, 10, 1), duration: 1, path: nil)])
        let before = try FileManager.default.contentsOfDirectory(atPath: home.locations.recordings.path).sorted()
        #expect(try home.store.recordings().map(\.id) == ["NEW", "OLD"])
        #expect(try FileManager.default.contentsOfDirectory(atPath: home.locations.recordings.path).sorted() == before)
    }

    @Test func matchingAnIDOrATitle() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.database([
            .init(key: 1, id: "AAAA1111-0000", title: "Team call", date: coreData(2026, 10, 1), duration: 1, path: nil),
            .init(key: 2, id: "AAAA2222-0000", title: "Team call notes", date: coreData(2026, 10, 2), duration: 1, path: nil),
            .init(key: 3, id: "BBBB3333-0000", title: "Dentist", date: coreData(2026, 10, 3), duration: 1, path: nil),
        ])
        let all = try home.store.recordings()
        #expect(try home.store.recording(matching: "bbbb", in: all).title == "Dentist")
        #expect(try home.store.recording(matching: "team call", in: all).id == "AAAA1111-0000")   // exact title beats contained
        #expect(try home.store.recording(matching: "dent", in: all).id == "BBBB3333-0000")
        #expect(throws: RecordingsError.self) { try home.store.recording(matching: "AAAA", in: all) }  // two ids
        #expect(throws: RecordingsError.self) { try home.store.recording(matching: "team", in: all) }  // two titles
        #expect(throws: RecordingsError.notFound("nothing")) { try home.store.recording(matching: "nothing", in: all) }
    }

    @Test func savedTranscriptsLiveOutsideVoiceMemos() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        try home.database([.init(key: 1, id: "AAAA1111", title: "Call", date: coreData(2026, 10, 1), duration: 9, path: "c.m4a", flags: 4)])
        try home.file("c.m4a", words: nil, recorder: "x", uuid: "AAAA1111")
        let call = try #require(try home.store.recordings().first)
        #expect(try home.store.transcript(for: call) == nil)
        let made = Transcript(source: .transcribed, locale: "en_GB", words: [TimedWord(text: "Hello", start: 0, end: 1)],
                              turns: [SpeakerTurn(speaker: "Speaker 1", start: 0, end: 1, text: "Hello")])
        try home.store.save(made, for: call)
        #expect(try home.store.transcript(for: call) == made)
        #expect(home.store.savedTranscriptURL(for: call).path.hasPrefix(home.locations.transcripts.path))
        #expect(!FileManager.default.fileExists(atPath: home.locations.recordings.appendingPathComponent("AAAA1111.json").path))
    }

    @Test func refusalAndAbsence() throws {
        let home = try FixtureHome()
        defer { home.remove() }
        #expect(throws: RecordingsError.noStore(home.locations.database.path)) { try home.store.recordings() }
        try home.database([])
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: home.locations.recordings.path)
        #expect(throws: RecordingsError.needsFullDiskAccess(home.locations.database.path)) { try home.store.recordings() }
    }
}

struct TextTests {

    var transcript: Transcript {
        Transcript(source: .voiceMemos, words: words.map { TimedWord(text: $0.0, start: $0.1, end: $0.2) })
    }

    @Test func tsrpJSONIsReadAsVoiceMemosWritesIt() throws {
        let file = FixtureHome.m4a(words: words, recorder: "com.apple.VoiceMemos (iPhone Version 27.0.1)", uuid: "U-1")
        let facts = TranscriptParsing.facts(file)
        #expect(facts.device == .iPhone && facts.uuid == "U-1" && facts.recorder == "com.apple.VoiceMemos (iPhone Version 27.0.1)")
        #expect(facts.transcript?.words.first == TimedWord(text: "Pick", start: 0.5, end: 0.8))
        #expect(TranscriptParsing.facts(FixtureHome.m4a(words: nil, recorder: "", uuid: "")).transcript == nil)
        #expect(TranscriptParsing.facts(Data("not a file".utf8)).transcript == nil)
        // A box claiming more bytes than there are ends the walk, not the process.
        #expect(MP4Atoms.boxes(Data([0, 0, 0, 200]) + Data("moov".utf8)).isEmpty)
    }

    @Test func linesBreakAtSentencesAndPauses() {
        let lines = TranscriptText.lines(transcript)
        #expect(lines.map(\.text) == ["Pick up the parcel on Friday.", "Then call the café back?"])
        #expect(lines[1].start == 4.5 && lines[1].end == 6.2)
        let unpunctuated = Transcript(source: .transcribed, words: [
            TimedWord(text: "one", start: 0, end: 1), TimedWord(text: " two", start: 1, end: 2), TimedWord(text: " three", start: 5, end: 6),
        ])
        #expect(TranscriptText.lines(unpunctuated).map(\.text) == ["one two", "three"])
        #expect(TranscriptText.timed(transcript).hasPrefix("[0:00] Pick up"))
        #expect(TranscriptText.clock(3_725) == "1:02:05")
    }

    @Test func subtitlesAndChunks() {
        let srt = TranscriptText.subtitles(transcript, format: .srt)
        #expect(srt.hasPrefix("1\n00:00:00,500 --> 00:00:02,300\nPick up the parcel on Friday."))
        #expect(TranscriptText.subtitles(transcript, format: .vtt).hasPrefix("WEBVTT"))
        let chunks = TranscriptText.chunks(transcript, limit: 40)
        #expect(chunks.count == 2 && chunks[1].hasPrefix("[0:04] Then call"))
    }

    @Test func speakerTurnsWin() {
        let turns = Transcript(source: .transcribed, words: [], turns: [
            SpeakerTurn(speaker: "Speaker 1", start: 0, end: 3, text: "Hello there."),
            SpeakerTurn(speaker: "Speaker 2", start: 3, end: 5, text: "Hi."),
        ])
        #expect(TranscriptText.plain(turns) == "Speaker 1: Hello there.\nSpeaker 2: Hi.")
        #expect(TranscriptText.lines(turns).map(\.speaker) == ["Speaker 1", "Speaker 2"])
    }

    @Test func searchFindsWordsAndWhenTheyWereSaid() {
        let recording = Recording(id: "R1", title: "Errands", date: Date(timeIntervalSince1970: 0), duration: 7)
        let hits = RecordingSearch.matches("CAFE", in: [recording], transcripts: ["R1": transcript])
        #expect(hits.count == 1 && hits[0].field == "transcript" && hits[0].at == 5.2)
        #expect(hits[0].snippet.contains("café"))
        #expect(RecordingSearch.matches("errand", in: [recording], transcripts: [:]).map(\.field) == ["title"])
        // Word starts only: "the" twice and "Then"; never inside a word.
        #expect(RecordingSearch.matches("the", in: [recording], transcripts: ["R1": transcript]).count == 3)
        #expect(RecordingSearch.matches("arcel", in: [recording], transcripts: ["R1": transcript]).isEmpty)
        #expect(RecordingSearch.matches("rands", in: [recording], transcripts: [:]).isEmpty)
        #expect(RecordingSearch.matches("  ", in: [recording], transcripts: ["R1": transcript]).isEmpty)
    }

    @Test func statistics() {
        var a = Recording(id: "a", title: "a", date: Date(timeIntervalSince1970: 1_790_000_000), duration: 10, transcribed: true, hasTranscript: true, device: .iPhone)
        a.favorite = true
        let b = Recording(id: "b", title: "b", date: Date(timeIntervalSince1970: 1_791_000_000), duration: 30, folder: "Work", deleted: Date(), transcribed: true)
        let c = Recording(id: "c", title: "c", date: Date(timeIntervalSince1970: 1_792_000_000), duration: 20, audioInICloudOnly: true)
        let stats = RecordingStatistics.stats([a, b, c])
        #expect(stats.recordings == 3 && stats.seconds == 60 && stats.averageSeconds == 20 && stats.longestID == "b")
        #expect(stats.withTranscript == 1 && stats.transcribedSilent == 1 && stats.notTranscribed == 1)
        #expect(stats.favorites == 1 && stats.deleted == 1 && stats.inICloudOnly == 1)
        #expect(stats.byDevice == ["iPhone": 1, "unknown": 2] && stats.byFolder["Work"] == 1)
    }
}
