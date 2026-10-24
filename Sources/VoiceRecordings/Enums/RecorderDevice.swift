//
//  RecorderDevice.swift
//  VoiceRecordings
//
//  Created by David Sherlock on 2026.
//

/// The kind of device a recording was made on, from the app that wrote it.
public enum RecorderDevice: String, Codable, Sendable, CaseIterable {
    case iPhone

    /// The Mac's Voice Memos is the iPad app (Mac Catalyst) and names itself
    /// "iPad Version" in the file — a Mac and an iPad cannot be told apart.
    case iPadOrMac

    case watch
    case unknown
}
