# Room interaction and voice stage

Latest user instruction (2026-10-12): use demo interaction without an on-screen demo label. This supersedes the earlier request to show recording/preview copy on the room stage. The app still has no remote chat, presence, gift or RTC transport.

- `KokoRoomDemoSession` supplies transient catalogue-room messages, gift cues, audience arrivals/departures and a speaking-seat cue. It runs only while this view is active. It does not create follows, private messages, wallet history, coin spends or persistent room messages.
- Online labels and the audience sheet share one deduplicated roster. All roster members resolve to existing profiles. User-created rooms do not receive scripted guests.
- Demo entries and audience members use the existing report/block filters. Stable script IDs preserve hiding after a report. Own sends and confirmed purchases still use the existing journal and coin-accounting paths. Only the copied presentation room includes scripted entries; mutation panels receive the original room.
- Video removes the duplicate title, recording subtitle, bottom explanation and empty-chat instruction. Other-user lines arrive progressively; existing barrage lanes and gift ribbons animate these events.
- Voice removes the large people hero. Compact microphone seats scroll separately from the pinned chat feed; gift ribbons stay in that feed area. Only one gift button remains. Microphone preparation and permissions are unchanged.
- Voice seat and stage PNGs are newly generated with Garden `gpt-image-2` Host-Native guidance and built-in `image_gen`. Taste/Design and the web Garden skills were evaluated; no web artifact is involved. Prompt files and provenance are in this folder. Full PNG copies are preserved in `assets/original-ui/voice-orbit-room` and the asset catalogue; no procedural artwork or cropped derivative was made.
- New interface and scripted-message copy is bundled in all five supported languages.

Validation: source/diff and asset-reference inspection; localization resources and XcodeGen project regenerated. No compile, tests, analyzer or simulator execution. On-device layout, timing, permission behavior and animation performance remain unverified.
