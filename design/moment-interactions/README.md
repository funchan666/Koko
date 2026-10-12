# Moment detail interactions

2026-10-12 request: top-right content options, full-screen video, per-moment likes and comments with varied sample activity, and reporting/blocking comment authors.

- Detail header and full-screen player both expose More. Comment rows expose their own options. Report uses the existing reason chooser; block requires confirmation. Existing success feedback, local receipts and visibility filters are retained.
- Only one `KokoMomentPlayback` and `AVPlayer` exist per detail. Switching full screen replaces the inline player layer, preserves time/mute state and starts playback. Back from full screen preserves playback; leaving the detail tears it down. Backgrounding or opening safety controls pauses it. Hidden/blocked moments close the player.
- Own likes toggle the account journal set; own comments are persisted and removable. List cards and detail share like/comment counts. Reported comments and blocked authors are filtered immediately and after restart.
- `KokoMomentConversationSeeds` is sample catalogue engagement, not remote activity. Each of the 54 supplied media entries has an individually written opening comment, two to four total sample comments with varied authors, and a deterministic sample like count. Only 46 are available in Moments because 8 recordings belong to the separate live-room catalogue. User likes add at most one to the sample count; samples do not write to account journals or create relationships.
- Existing project-original More/control surfaces are reused. Full-screen expand artwork is newly generated with Garden / GPT Image 2 Host-Native guidance and built-in `image_gen`; Taste/Design/web skills were evaluated for scope and no web implementation is involved. The transparent PNG is copied whole, unmodified, into `assets/original-ui/moment-interactions` and the asset catalogue. Prompt and provenance sit beside this file.
- New control labels support the existing five languages. Sample comments remain English catalogue content, like the supplied captions; they are not presented as user-authored translations.

Verification: source/configuration/diff inspection, catalog seed coverage, image references, strings validation and XcodeGen generation only. No build, tests, analyzer, simulator or device run. Full-screen layout and runtime playback remain unverified.
