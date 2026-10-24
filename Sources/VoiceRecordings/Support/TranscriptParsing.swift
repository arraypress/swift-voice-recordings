//
//  TranscriptParsing.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//
//  Voice Memos' transcript is the `tsrp` box's JSON — Swift's AttributedString
//  in its Codable form. MEASURED shape:
//
//    {"locale": {"identifier": "en_GB", …},
//     "attributedString": {"runs": ["Hi", 0, " Claude,", 1, …],
//                          "attributeTable": [{"timeRange": [1.32, 1.62]}, …]}}
//
//  `runs` alternates text and an index into `attributeTable`; a run's time
//  range is its attribute's `timeRange`. A recording with no speech carries
//  an empty `attributedString`. Also reads the device from `©too`.
//

import Foundation

/// Reading what Voice Memos stores in a recording's file.
public enum TranscriptParsing {

    /// The transcript in a recording's `tsrp` JSON, or `nil` when it holds no words.
    public static func transcript(tsrp json: Data) -> Transcript? {
        guard let root = try? JSONSerialization.jsonObject(with: json) as? [String: Any] else { return nil }
        let attributed = root["attributedString"] as? [String: Any] ?? [:]
        let table = attributed["attributeTable"] as? [[String: Any]] ?? []
        var words: [TimedWord] = []
        var pendingText: String?
        for run in attributed["runs"] as? [Any] ?? [] {
            if let text = run as? String {
                if let pendingText { words.append(TimedWord(text: pendingText)) }
                pendingText = text
            } else if let index = (run as? NSNumber)?.intValue, let text = pendingText {
                let range = table.indices.contains(index) ? table[index]["timeRange"] as? [Double] : nil
                words.append(TimedWord(text: text, start: range?.first, end: range?.last))
                pendingText = nil
            }
        }
        if let pendingText { words.append(TimedWord(text: pendingText)) }
        guard words.contains(where: { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) else { return nil }
        return Transcript(source: .voiceMemos, locale: locale(root["locale"]), words: words)
    }

    /// The locale identifier, whichever way it was encoded.
    static func locale(_ value: Any?) -> String? {
        if let text = value as? String { return text }
        if let object = value as? [String: Any] { return object["identifier"] as? String ?? object["localeIdentifier"] as? String }
        return nil
    }

    /// What a recording's file says about itself.
    public struct FileFacts: Sendable, Hashable {
        public var transcript: Transcript?
        public var recorder: String?
        public var device: RecorderDevice
        public var uuid: String?
    }

    /// Everything Voice Memos wrote into a recording's file.
    public static func facts(_ file: Data) -> FileFacts {
        let boxes = MP4Atoms.boxes(file)
        let recorder = MP4Atoms.itemString("©too", in: file, boxes: boxes)
        return FileFacts(
            transcript: MP4Atoms.payload("tsrp", in: file, boxes: boxes).flatMap { transcript(tsrp: $0) },
            recorder: recorder,
            device: device(recorder),
            uuid: MP4Atoms.freeform("voice-memo-uuid", in: file, boxes: boxes)
        )
    }

    /// The device in a `©too` string such as
    /// `com.apple.VoiceMemos (iPhone Version 27.0.1 (Build 24A446))`.
    public static func device(_ recorder: String?) -> RecorderDevice {
        guard let recorder else { return .unknown }
        if recorder.contains("iPhone") { return .iPhone }
        if recorder.contains("iPad") { return .iPadOrMac }
        if recorder.localizedCaseInsensitiveContains("watch") { return .watch }
        return .unknown
    }
}
