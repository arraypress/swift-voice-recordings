//
//  Recording.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// One recording in the Voice Memos library, every column decoded.
public struct Recording: Codable, Sendable, Hashable, Identifiable {

    /// The recording's unique id (a UUID string; also in its file).
    public var id: String

    /// Its title — the one Voice Memos shows.
    public var title: String

    /// When it was recorded.
    public var date: Date

    /// Its length in seconds.
    public var duration: Double

    /// The audio file's path, whether or not it is on disk.
    public var file: String?

    /// Whether the audio file is on this Mac.
    public var fileExists: Bool

    /// The user folder it is in, if any.
    public var folder: String?

    /// When it was deleted: it is in Recently Deleted until erased.
    public var deleted: Date?

    public var favorite: Bool
    public var enhanced: Bool
    public var musicMemo: Bool
    public var recordedOnWatch: Bool

    /// The audio is only in iCloud: Voice Memos has not downloaded it.
    public var audioInICloudOnly: Bool

    /// Voice Memos has transcribed it, and whether that found any words.
    public var transcribed: Bool
    public var hasTranscript: Bool

    /// Recorded as layers (multiple tracks), or in spatial audio.
    public var layered: Bool
    public var spatial: Bool

    public var manuallyRenamed: Bool
    public var skipSilence: Bool
    public var studioVoice: Bool

    /// Where playback was left, in seconds, and the playback speed.
    public var playbackPosition: Double?
    public var playbackSpeed: Double?

    /// The device and app version that made it, from the file.
    public var device: RecorderDevice
    public var recorder: String?

    /// The store's raw flag words, for anything not decoded above.
    public var flags: Int
    public var sharedFlags: Int

    public init(
        id: String, title: String, date: Date, duration: Double, file: String? = nil, fileExists: Bool = false,
        folder: String? = nil, deleted: Date? = nil, favorite: Bool = false, enhanced: Bool = false,
        musicMemo: Bool = false, recordedOnWatch: Bool = false, audioInICloudOnly: Bool = false,
        transcribed: Bool = false, hasTranscript: Bool = false, layered: Bool = false, spatial: Bool = false,
        manuallyRenamed: Bool = false, skipSilence: Bool = false, studioVoice: Bool = false,
        playbackPosition: Double? = nil, playbackSpeed: Double? = nil, device: RecorderDevice = .unknown,
        recorder: String? = nil, flags: Int = 0, sharedFlags: Int = 0
    ) {
        self.id = id
        self.title = title
        self.date = date
        self.duration = duration
        self.file = file
        self.fileExists = fileExists
        self.folder = folder
        self.deleted = deleted
        self.favorite = favorite
        self.enhanced = enhanced
        self.musicMemo = musicMemo
        self.recordedOnWatch = recordedOnWatch
        self.audioInICloudOnly = audioInICloudOnly
        self.transcribed = transcribed
        self.hasTranscript = hasTranscript
        self.layered = layered
        self.spatial = spatial
        self.manuallyRenamed = manuallyRenamed
        self.skipSilence = skipSilence
        self.studioVoice = studioVoice
        self.playbackPosition = playbackPosition
        self.playbackSpeed = playbackSpeed
        self.device = device
        self.recorder = recorder
        self.flags = flags
        self.sharedFlags = sharedFlags
    }
}

/// A user folder.
public struct RecordingFolder: Codable, Sendable, Hashable {
    public var id: String?
    public var name: String
    public var recordings: Int
    public var rank: Int?

    public init(id: String?, name: String, recordings: Int, rank: Int? = nil) {
        self.id = id
        self.name = name
        self.recordings = recordings
        self.rank = rank
    }
}
