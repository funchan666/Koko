# Room activity and controls

## UI routing

This is a focused native SwiftUI revision. Taste/Design/Garden routing was evaluated; no browser artifact or HTML prototype is required. Garden `gpt-image-2` Host-Native plus `imagegen` created the original `KokoRoomGiftRibbon` skin. Existing project-owned room control and keepsake artwork is retained. New asset generation input: [prompt.txt](prompt.txt). Source and unchanged file hash: [provenance.json](provenance.json).

## Delivered changes

- One gift entrance in the bottom composer. Removed the duplicate side entrance from the video stage and the duplicate tool-row entrance from the voice room, which shares the composer.
- More is beside Leave at the top right. Sound remains beside the chat area.
- Persisted new text entries are scheduled across three fixed lanes. New arrivals no longer shift existing lanes or replace the previous three messages.
- Real gift entries use two queued ribbon lanes and one enlarged floating keepsake per event. Gift names and quantities come from the persisted transaction message; no artificial senders, counts, messages, or gift spending are introduced.
- Tapping a moving message/ribbon opens its author's profile. Decorative animation is hidden from VoiceOver; the persistent chat log remains its accessible equivalent with profile/report actions.
- Reduce Motion removes travel/rotation and shows timed static messages/ribbons. Leaving, changing rooms or backgrounding clears presentation state. Returning does not replay old gifts as new activity.
- Effects are removed when their source entry becomes hidden by reporting/blocking. Expired entries are retired by a cancellable task, allowing empty TimelineViews to pause. Playback cleanup is preserved.
- Existing recorded-video/local-interaction disclosure, the eight-gift catalog, spend confirmation and atomic wallet/room write path are unchanged.

The new PNG is copied unchanged into `assets/original-ui/live-room-activity/` and the asset catalog. Native background layout accounts for the image's transparent export margins; no new raster crop or synthesized art is used.

## Static verification only

Reviewed source changes, route callbacks, observable room updates, lifecycle cleanup and asset references. XcodeGen regenerated the project. Git whitespace and resource JSON checks passed. No build, tests, analyzer, simulator, device run or purchase was performed; animation timing, touch behavior and rendered layout require runtime acceptance.

## Voice room extension

Voice rooms now own an independent `KokoRoomStageActivity` queue and use the same three text lanes, two gift lanes and original ribbon artwork. Effects are anchored to the scroll viewport so the room header, bottom microphone/music tools and composer remain outside the effect area; scrolling does not carry the effects offscreen. In short viewports, pending gifts take priority over text effects. Source entries still remain in chat history. Voice-room entry, exit, room changes, foreground/background transitions and filtered conversation changes drive the same reset and visibility rules as the video stage. The only gift picker entrance is the bottom composer; More remains in the upper-right room header.

Static source/diff and existing project-reference inspection completed for this extension. No compilation, tests, analyzer or simulator run.
