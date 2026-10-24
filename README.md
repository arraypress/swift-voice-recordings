# swift-voice-recordings

The Mac's Voice Memos library, read-only: every recording (iPhone recordings arrive by iCloud), its flags, its folder, and the transcript Voice Memos keeps inside each file — with the time of every word — plus search, statistics, subtitles and model-sized chunks. No Apple framework is linked, and nothing in Voice Memos' container is ever written.

```swift
import VoiceRecordings

let store = RecordingStore()
let recordings = try store.recordings()            // newest first, Recently Deleted flagged
if let memo = recordings.first, let transcript = try store.transcript(for: memo) {
    print(TranscriptText.timed(transcript))        // [0:04] Can you understand me?
    print(TranscriptText.srt(transcript))
}
let hits = RecordingSearch.matches("invoice", in: recordings, transcripts: [:])
```

## Where the data is

`~/Library/Group Containers/group.com.apple.VoiceMemos.shared/Recordings/`:

| What | Where |
| --- | --- |
| The library | `CloudRecordings.db` — Core Data, mirrored to iCloud; table `ZCLOUDRECORDING`, folders in `ZFOLDER` |
| The audio | `<date> <time>[-<id>].m4a` beside it (`ZPATH`) |
| The transcript | inside each `.m4a`, in a `tsrp` box (`moov/trak/udta/tsrp`) |
| Who recorded it | the `.m4a`'s `©too` item — `com.apple.VoiceMemos (iPhone Version 27.0.1 …)` |

All of it sits behind **Full Disk Access**. The database and its `-wal`/`-shm` are copied to a private folder and read there. Transcripts this library's users make themselves are kept in `~/Library/Application Support/voice-recordings/transcripts`, never beside the recordings.

## The formats (measured on macOS 27.0.1)

- **Flags.** Read through Apple's own `RCCloudRecording` (VoiceMemos.framework, loaded in a Mac Catalyst probe over its own Core Data model), one bit at a time. `ZFLAGS`: 2 audio only in iCloud, 4 playable, 8 renamed by hand, 64 recorded on Apple Watch, 256 needs export, **512 transcribed, 1024 a transcript exists**, 2048 layered, 4096 spatial. `ZSHAREDFLAGS`: 1 favourite, 2 enhanced, 4 music memo, 64 watchOS. A recording transcribed with no speech in it carries 512 without 1024.
- **Recently Deleted** is not a flag: Apple's `deletionDate` returns `ZEVICTIONDATE`.
- **Titles** are plain text in `ZENCRYPTEDTITLE` — "encrypted" is CloudKit's field type, not local encryption. Default titles are a place name or "New Recording N".
- **The transcript** is Swift's `AttributedString` in its Codable form: `runs` alternating text and an index into `attributeTable`, whose entries carry `timeRange: [start, end]`. A recording with no speech has an empty `attributedString`.
- **The device**: the Mac's Voice Memos is the iPad app (Mac Catalyst) and writes `iPad Version`, so a Mac and an iPad cannot be told apart (`RecorderDevice.iPadOrMac`).

## What it offers

- `RecordingStore` — `recordings()`, `folders()`, `recording(matching:in:)` (an id, an id's first characters, or a title; two equal matches are refused with both), `transcript(for:)` (Voice Memos' own, else one saved here), `save(_:for:)`, `audio(for:)`.
- `TranscriptText` — the plain text, sentence lines with times (breaking at `.?!`, a pause, or twelve seconds), `timed`, `srt`, `vtt`, and `chunks(limit:)` for a model with a small context. Speaker turns, when a transcript has them, win.
- `RecordingSearch` — titles and transcripts, ignoring case and accents; a match starts a word, and a transcript match carries the second it was said.
- `RecordingStatistics` — totals, transcribed / no speech / not transcribed, favourites, deleted, by device, folder and month.

## Measured

On one Mac (macOS 27.0.1, Voice Memos 27.0.1): every recording's flags decoded as Apple's own class reads them; an iPhone recording's transcript read word for word, its times matching the recording; the fleet's own transcriber (`transcribe`, Apple's SpeechAnalyzer) heard the same words as the stored transcript.

## Requirements

macOS 14 or later. Swift 6.2. Depends on swift-subtitle-kit.

## Licence

MIT.
