//
//  RecordingStatistics.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// Counting recordings.
public enum RecordingStatistics {

    /// Totals, and counts by device, folder and month (`2026-10`, local time).
    public static func stats(_ recordings: [Recording], calendar: Calendar = .current) -> RecordingStats {
        let seconds = recordings.map(\.duration).reduce(0, +)
        let longest = recordings.max { $0.duration < $1.duration }
        func count(_ key: (Recording) -> String) -> [String: Int] {
            recordings.reduce(into: [:]) { $0[key($1), default: 0] += 1 }
        }
        return RecordingStats(
            recordings: recordings.count,
            seconds: seconds,
            averageSeconds: recordings.isEmpty ? 0 : seconds / Double(recordings.count),
            longestSeconds: longest?.duration ?? 0,
            longestID: longest?.id,
            first: recordings.map(\.date).min(),
            last: recordings.map(\.date).max(),
            withTranscript: recordings.filter(\.hasTranscript).count,
            transcribedSilent: recordings.filter { $0.transcribed && !$0.hasTranscript }.count,
            notTranscribed: recordings.filter { !$0.transcribed }.count,
            favorites: recordings.filter(\.favorite).count,
            deleted: recordings.filter { $0.deleted != nil }.count,
            inICloudOnly: recordings.filter(\.audioInICloudOnly).count,
            byDevice: count { $0.device.rawValue },
            byFolder: count { $0.folder ?? "(no folder)" },
            byMonth: count { recording in
                let parts = calendar.dateComponents([.year, .month], from: recording.date)
                return String(format: "%04d-%02d", parts.year ?? 0, parts.month ?? 0)
            }
        )
    }
}
