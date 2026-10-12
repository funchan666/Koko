# Broadcast room identification

Original coral enamel badge with cream signal bars, generated for Koko with the built-in image tool using Garden GPT Image 2 Host-Native guidance. Prompt and provenance are beside this file. Full PNG copied unchanged into `assets/original-ui/live-room-status` and the artwork catalog. No cropping, raster manipulation or code-drawn replacement artwork.

Placement: top-left of each Discover video-room cover, with a 9-point inset. The same semantic badge appears beside the title in the video stage. Its 118 × 40-point layout uses native localized text over original artwork, no button border and no simulated activity animation. It does not intercept room-cover taps.

The title identifies the room category, not a claim of a connected broadcast. The current playback source is supplied recordings, so the subtitle says Recorded preview; a room without a recording says Not broadcasting. No remote LIVE status, viewer count or fake online event is fabricated. A future real broadcast status must be driven by the connected service.

Skill routing: Taste and Design evaluated for scope; this is a focused native SwiftUI asset integration, not a web redesign, HTML prototype or design exploration. Garden gpt-image-2 and imagegen apply. Existing native stack and local typefaces retained.

Verification: generated artwork inspected, source references, five-language resources, catalog metadata and original-file hashes inspected; XcodeGen regenerated. No build, tests, analyzer, simulator or device run.

## Compact directory cards and decorative motion

Video-directory cards use a 350 pt base height (previously 380), scaling with Dynamic Type; their cover occupies 53% so title/host/action space is preserved. The shared editorial layout retains its 380 pt / 55.4% defaults for moment cards. Voice cards use 172 pt (previously 188), preserve a 44+ pt join area and reduce row spacing from 16 to 14 pt.

Both card types apply a 3.4-second gentle 0.98–1.02 scale / 0.86–1 opacity breath to original signal artwork. This is decorative emphasis, not microphone activity or remote LIVE status. Existing truthful preview labels remain unchanged. The timeline pauses with view disappearance, inactive scene phase or Reduce Motion. Native layout/animation reuses the original raster assets without pixel editing or new shape drawing. Taste/Design/Garden routing was evaluated for a small native refinement; existing Garden artwork is reused, with no new web/design artifact required.

Source, resource references and Git diff inspection only; no compile, tests, analyzer or simulator run. Runtime visual acceptance remains outstanding.

## Directory label refinement

Per the latest screenshot feedback, Discover cards now use a compact 106 × 32 pt single-line badge: only `Live room` is visible, centered in the label area. `showsStatusDetail` defaults to true for the in-room badge; recording disclosure and accessibility context remain available. Existing original artwork is reused with native text/layout only. Static diff inspection passed; no build or simulator execution.

## Corrected target: cream information area

The user's follow-up identifies the cream footer, not the cover, as the oversized part. Live cards now retain the current 185.5 pt cover and use a 124 pt base details area (down from 164.5 pt). Topic/title form the upper room-entry hit area; the host profile and Enter room action share the bottom row, each retaining a 44 pt minimum hit height. No expanding Spacer separates those rows. Both dimensions scale with Dynamic Type and all live cards share the same height. Moment cards keep their existing standard detail layout. Existing original artwork and badge motion are retained without raster editing. Source/diff review only; no compilation or runtime validation.

## Discover header spacing refinement

The screenshot's boxed header group is now more compact: hero base height 190→170 pt, hero title 26→24 pt, native group gaps 18→12 pt, search minimum height 52→46 pt, category icons 24→21 pt and category row/column gaps 8→6 pt. Category taps remain at least 44 pt. Only Discover opts into the compact search variant; other screens keep their existing search dimensions. Native layout reuses the established original Garden artwork, without new raster edits or code-drawn replacements. Taste/Design/Garden routing remains scoped to this native layout refinement. Static diff and callback inspection only; runtime appearance unverified.
