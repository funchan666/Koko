# Room creation and independent covers

## Native design

The video and voice room composers share a bounded SwiftUI form with a compact cover editor, grouped fields, two-column topic choices and a persistent bottom action. Microphone-seat choices appear on the voice composer. Accessibility text sizes stack cover editing and topic choices. Keyboard focus scrolls the current field into view. The page respects KokoScreenCanvas insets and has no additional ignoresSafeArea modifiers.

Garden / GPT Image 2 Host-Native and the built-in image tool produced two original cover invitation illustrations, one for video and one for voice. Taste, Claude Design and browser Garden routes were evaluated; the implementation remains native. Existing original Koko profile-editor surfaces, background and photo-operation icons are reused consistently. Generated PNGs are copied unchanged into `assets/original-ui/room-composer/` and KokoArtwork.xcassets. Prompts and SHA-256 provenance are beside this document.

## Cover flow

- Genuine PhotosPicker selects one image; existing JPEG preparation corrects orientation, limits the maximum image dimension to 900 pixels and omits source metadata.
- The real AVFoundation photo page is reused with room-specific heading and return wording. It supports capture, retake and camera switching. It does not request microphone access.
- An initial denied camera request returns quietly. Only a subsequent active request with previously denied permission offers the existing neutral Settings action. Restricted access has no Settings action. Async import and permission completions are guarded by view lifetime, account ID and operation revision.
- Import failure preserves the previous selected cover; Remove photo returns to the original invitation illustration. No profile mutation occurs.
- Optional `HostedConversationRoom.roomCoverJPEG` is encoded with the room inside the existing atomically written account archive. Missing keys remain compatible with old room records. Room creation only navigates after saveRoom succeeds; text validation and content checks remain in place. Account deletion removes the cover with its archive, with no separate cover-file cleanup required.
- Shared KokoRoomCoverPhoto reads custom cover data first. Both directories and video-stage fallback use it; a custom voice cover also appears in the room header. Existing supplied demo-room media remains the fallback for those existing rooms. New rooms without a chosen image use the original invitation illustration rather than the host avatar.

This change provides local room-cover selection and persistence through the existing room creation flow. It does not add remote image upload or a broadcasting backend.

## Static verification

Inspected model coding keys, saveRoom/update/persist path, room-cover call sites and asynchronous cancellation guards. Both PNG copies match generated-source hashes. All new labels exist in English, Simplified Chinese, Spanish, French and Japanese without duplicate localization keys. Camera permission descriptions now include room covers in all five locales and the base plist. Property-list/string syntax and Git whitespace checks pass.

No compilation, tests, analyzer, simulator or device run was performed. Runtime photo capture, persistence after relaunch and visual layout still require device acceptance. Prior profile-editor changes and unrelated project-file changes were preserved.
