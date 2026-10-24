//
//  RecordingFlags.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//
//  The bits of ZFLAGS and ZSHAREDFLAGS. MEASURED on macOS 27.0.1, not
//  guessed: Apple's own RCCloudRecording (VoiceMemos.framework, loaded in a
//  Mac Catalyst probe over its own Core Data model) was given one bit at a
//  time and asked for each property. Bits that changed nothing are unnamed.
//  The deletion date is not a bit: RCCloudRecording.deletionDate returns
//  ZEVICTIONDATE — a recording with one is in Recently Deleted.
//

/// Decoding the flag words.
public enum RecordingFlags {

    // ZFLAGS
    public static let audioNeedsDownload = 1 << 1
    public static let playable = 1 << 2
    public static let manuallyRenamed = 1 << 3
    public static let recordedOnWatch = 1 << 6
    public static let audioNeedsExport = 1 << 8
    public static let hasBeenTranscribed = 1 << 9
    public static let transcriptExists = 1 << 10
    public static let multipleTracks = 1 << 11
    public static let spatial = 1 << 12

    // ZSHAREDFLAGS
    public static let favorite = 1 << 0
    public static let enhanced = 1 << 1
    public static let musicMemo = 1 << 2
    public static let watchOS = 1 << 6

    /// Whether `bit` is set in `word`.
    public static func has(_ word: Int, _ bit: Int) -> Bool { word & bit != 0 }
}
